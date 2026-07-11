
%  DESCRIPTION:
%    This script builds a fully interactive real-time GUI that allows the
%    user to steer the acoustic beam by dragging three sliders (X, Y, Z).
%    Every slider movement triggers a complete re-computation of:
%      (1) DAS steering weights for the new target direction
%      (2) The 3D pressure field via wave superposition (35x35x35 grid)
%      (3) SPL in dB, isosurface extraction, and orthogonal slice rendering
%    The result is a live visualization of the beam lobe chasing the target.
%
%  ARCHITECTURE — WHY A NESTED FUNCTION?
%    The callback `updateBeam` is a NESTED function inside `step4_interactive_gui`.
%    In MATLAB, nested functions share the workspace of their parent function.
%    This means `updateBeam` can directly READ and WRITE variables declared
%    in the main function body (array_coords, k, ax, X_grid, etc.) without:
%      - global variables  (pollute the base workspace, cause state bugs)
%      - guidata/setappdata (verbose, requires explicit pack/unpack every call)
%      - persistent variables (shared across ALL calls, not per-instance safe)
%    The nested function pattern is the cleanest, most MATLAB-idiomatic way
%    to give a callback access to pre-computed data and handles.
%
%  PREREQUISITES (must exist in BASE WORKSPACE from Steps 1 & 2):
%    - array_coords  : 100x3  transducer position matrix [m]
%    - k             : wave number = 2*pi/lambda [rad/m]
%    - lambda        : wavelength [m]
%    - f             : carrier frequency [Hz]
%    - num_elements  : 100
%
%  HOW TO RUN:
%    >> step4_interactive_gui
%    Then drag the X / Y / Z sliders to steer the beam in real time.
%
%  NOTE: Uses ONLY core MATLAB functions. No Phased Array Toolbox.
% =========================================================================
function step4_interactive_gui()
%  SECTION 1: LOAD PREREQUISITE VARIABLES FROM BASE WORKSPACE


fprintf('\n============================================================\n');
fprintf('  STEP 4: LIVE INTERACTIVE GUI — REAL-TIME BEAM STEERING\n');
fprintf('============================================================\n');

try
    array_coords = evalin('base', 'array_coords');
    k            = evalin('base', 'k');
    lambda       = evalin('base', 'lambda');
    f            = evalin('base', 'f');
    num_elements = evalin('base', 'num_elements');
    fprintf('  Workspace variables loaded successfully from Steps 1-2.\n');
catch ME
    error(['Could not load required variables from base workspace.\n', ...
           'Please run Steps 1 and 2 first.\n', ...
           'Missing variable: %s'], ME.message);
end

% Validate dimensions
assert(size(array_coords, 1) == 100 && size(array_coords, 2) == 3, ...
       'array_coords must be 100x3. Re-run Step 1.');
assert(isscalar(k) && isreal(k) && k > 0, ...
       'k must be a positive real scalar. Re-run Step 1.');

fprintf('  array_coords : %dx%d  |  k = %.4f rad/m  |  lambda = %.4f mm\n\n', ...
        size(array_coords,1), size(array_coords,2), k, lambda*1e3);
%  SECTION 2: PRE-COMPUTE OBSERVATION GRID (DONE ONCE — NOT IN CALLBACK)

grid_pts  = 35;                                    
x_gv      = linspace(-2.0,  2.0, grid_pts);       
y_gv      = linspace(-2.0,  2.0, grid_pts);      
z_gv      = linspace( 0.1,  2.5, grid_pts);       

[X_grid, Y_grid, Z_grid] = meshgrid(x_gv, y_gv, z_gv);   

fprintf('  Observation grid  : %dx%dx%d  (%d points)\n', ...
        grid_pts, grid_pts, grid_pts, grid_pts^3);
fprintf('  X: [%.1f, %.1f] m  |  Y: [%.1f, %.1f] m  |  Z: [%.1f, %.1f] m\n\n', ...
        x_gv(1), x_gv(end), y_gv(1), y_gv(end), z_gv(1), z_gv(end));
%  SECTION 3: BUILD THE GUI — FIGURE, AXES, SLIDERS, LABELS
fig = figure('Name',         'Step 4 — Live Interactive Beam Steering GUI', ...
             'NumberTitle',  'off', ...
             'Color',        [0.10 0.10 0.12], ...   % Near-black background
             'Position',     [100, 100, 1000, 750], ...
             'Resize',       'on');
ax = axes('Parent',   fig, ...
          'Units',    'normalized', ...
          'Position', [0.06, 0.20, 0.86, 0.76], ...
          'Color',    [0.10 0.10 0.12], ...
          'GridColor',     [0.50 0.50 0.50], ...
          'GridAlpha',     0.30, ...
          'XColor',        [0.85 0.85 0.85], ...
          'YColor',        [0.85 0.85 0.85], ...
          'ZColor',        [0.85 0.85 0.85], ...
          'FontSize',      9, ...
          'Box',           'on', ...
          'BoxStyle',      'full');
slider_h      = 0.030;   
slider_w      = 0.22;    
slider_bot    = 0.060;   
label_bot     = 0.108;   
value_bot     = 0.018;   
x_left        = 0.08;
y_left        = 0.39;
z_left        = 0.70;
sliderX = uicontrol('Parent', fig, 'Style', 'slider', 'Units', 'normalized', ...
                    'Position', [x_left, slider_bot, slider_w, slider_h], ...
                    'Min', -2.0, 'Max', 2.0, 'Value', 1.0, ...
                    'SliderStep', [0.02, 0.10], ...
                    'BackgroundColor', [0.25 0.45 0.70]);
sliderY = uicontrol('Parent', fig, 'Style', 'slider', 'Units', 'normalized', ...
                    'Position', [y_left, slider_bot, slider_w, slider_h], ...
                    'Min', -2.0, 'Max', 2.0, 'Value', 1.0, ...
                    'SliderStep', [0.02, 0.10], ...
                    'BackgroundColor', [0.25 0.65 0.40]);
sliderZ = uicontrol('Parent', fig, 'Style', 'slider', 'Units', 'normalized', ...
                    'Position', [z_left, slider_bot, slider_w, slider_h], ...
                    'Min', 0.5, 'Max', 2.5, 'Value', 2.0, ...
                    'SliderStep', [0.02, 0.10], ...
                    'BackgroundColor', [0.70 0.35 0.25]);
label_style = {'Style', 'text', 'Units', 'normalized', ...
               'BackgroundColor', [0.10 0.10 0.12], 'ForegroundColor', [0.95 0.95 0.95], ...
               'FontSize', 9.5, 'FontWeight', 'bold', 'HorizontalAlignment', 'center'};
uicontrol(fig, label_style{:}, 'Position', [x_left, label_bot, slider_w, 0.030], 'String', 'Target X   [ -2.0 \rightarrow  2.0 ] m');
uicontrol(fig, label_style{:}, 'Position', [y_left, label_bot, slider_w, 0.030], 'String', 'Target Y   [ -2.0 \rightarrow  2.0 ] m');
uicontrol(fig, label_style{:}, 'Position', [z_left, label_bot, slider_w, 0.030], 'String', 'Target Z   [  0.5 \rightarrow  2.5 ] m');
value_style = {'Style', 'text', 'Units', 'normalized', 'BackgroundColor', [0.10 0.10 0.12], ...
               'FontSize', 9, 'HorizontalAlignment', 'center'};
txtX = uicontrol(fig, value_style{:}, 'Position', [x_left, value_bot, slider_w, 0.030], 'ForegroundColor', [0.55 0.80 1.00], 'String', 'X = 1.00 m');
txtY = uicontrol(fig, value_style{:}, 'Position', [y_left, value_bot, slider_w, 0.030], 'ForegroundColor', [0.55 1.00 0.65], 'String', 'Y = 1.00 m');
txtZ = uicontrol(fig, value_style{:}, 'Position', [z_left, value_bot, slider_w, 0.030], 'ForegroundColor', [1.00 0.70 0.50], 'String', 'Z = 2.00 m');
uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.30, 0.001, 0.40, 0.020], ...
          'BackgroundColor', [0.10 0.10 0.12], 'ForegroundColor', [0.55 0.55 0.55], ...
          'FontSize', 8, 'HorizontalAlignment', 'center', ...
          'String', 'Drag sliders to steer beam in real time  |  Yellow lobe = -15 dB beam boundary');
set(sliderX, 'Callback', @updateBeam);
set(sliderY, 'Callback', @updateBeam);
set(sliderZ, 'Callback', @updateBeam);

fprintf('  GUI constructed. Rendering initial beam frame...\n\n');
updateBeam([], []);
fprintf('  GUI ready. Drag sliders to steer the beam.\n');
fprintf('============================================================\n\n');
%  SECTION 4: NESTED CALLBACK FUNCTION — updateBeam

    function updateBeam(~, ~)
        % ---- Read current slider positions ----
        x_t = get(sliderX, 'Value');   
        y_t = get(sliderY, 'Value');   
        z_t = get(sliderZ, 'Value');   
        set(txtX, 'String', sprintf('X = %.3f m', x_t));
        set(txtY, 'String', sprintf('Y = %.3f m', y_t));
        set(txtZ, 'String', sprintf('Z = %.3f m', z_t));
        target = [x_t, y_t, z_t];   
        r_hat = target / norm(target);   
        k_vec = k * r_hat;   
        w = exp(-1j * (array_coords * k_vec.'));   

        P_total = zeros(size(X_grid));
        for n = 1:size(array_coords, 1)
            xn = array_coords(n, 1);
            yn = array_coords(n, 2);
            zn = array_coords(n, 3);   
            R = sqrt((X_grid - xn).^2 + (Y_grid - yn).^2 + (Z_grid - zn).^2);
            R(R < 1e-4) = 1e-4;
            P_total = P_total + (w(n) ./ R) .* exp(-1j * k * R);
        end
        P_mag = abs(P_total);   
        far_mask = Z_grid > 0.5;               
        peak_ff  = max(P_mag(far_mask));       
        SPL_dB = 20 * log10(P_mag / peak_ff);   
        SPL_dB(SPL_dB >  0)  =   0;   
        SPL_dB(SPL_dB < -20) = -20;   
        cla(ax);
        hold(ax, 'on');
        scatter3(ax, ...
                 array_coords(:,1), array_coords(:,2), array_coords(:,3), ...
                 30, 'filled', ...
                 'MarkerFaceColor', [0.15 0.90 0.90], ...
                 'MarkerEdgeColor', [0.05 0.55 0.55]);
        scatter3(ax, x_t, y_t, z_t, ...
                 200, 'filled', ...
                 'MarkerFaceColor', [1.00 0.18 0.18], ...
                 'MarkerEdgeColor', [0.80 0.00 0.00], ...
                 'LineWidth', 1.5);
        text(ax, x_t + 0.10, y_t, z_t + 0.12, ...
             sprintf(' (%.2f, %.2f, %.2f)', x_t, y_t, z_t), ...
             'Color',      [1.0 0.55 0.55], ...
             'FontSize',   8, ...
             'FontWeight', 'bold');
        slice(ax, X_grid, Y_grid, Z_grid, SPL_dB, 2.0, 2.0, 0.1);
        shading(ax, 'interp');        
        colormap(ax, jet);            
        clim(ax, [-20, 0]);           

        cb = colorbar(ax);
        cb.Color                = [0.90 0.90 0.90];
        cb.Label.String         = 'Normalized SPL  (dB re far-field peak)';
        cb.Label.Color          = [0.90 0.90 0.90];
        cb.Label.FontSize       = 9;
        cb.Label.FontWeight     = 'bold';
        iso_outer = isosurface(X_grid, Y_grid, Z_grid, SPL_dB, -15);
        if ~isempty(iso_outer.vertices)
            p_out = patch(ax, iso_outer);
            set(p_out, 'FaceColor', 'cyan', 'EdgeColor', 'none', 'FaceAlpha', 0.15);
            isonormals(X_grid, Y_grid, Z_grid, SPL_dB, p_out);
        end
        iso_inner = isosurface(X_grid, Y_grid, Z_grid, SPL_dB, -6);
        if ~isempty(iso_inner.vertices)
            p_in = patch(ax, iso_inner);
            set(p_in, 'FaceColor', 'yellow', 'EdgeColor', 'none', 'FaceAlpha', 0.65);
            isonormals(X_grid, Y_grid, Z_grid, SPL_dB, p_in);
        end
        camlight(ax, 'headlight');
        lighting(ax, 'gouraud');
        axis(ax, 'equal');
        axis(ax, 'tight');
        grid(ax, 'on');
        view(ax, 38, 26);   
        xlim(ax, [-2.2,  2.2]);
        ylim(ax, [-2.2,  2.2]);
        zlim(ax, [-0.2,  2.8]);
        xlabel(ax, 'X  (meters)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.92 0.92 0.92]);
        ylabel(ax, 'Y  (meters)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.92 0.92 0.92]);
        zlabel(ax, 'Z  (meters)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.92 0.92 0.92]);
        ax.Color      = [0.10 0.10 0.12];
        ax.GridColor  = [0.50 0.50 0.50];
        ax.GridAlpha  = 0.30;
        ax.XColor     = [0.85 0.85 0.85];
        ax.YColor     = [0.85 0.85 0.85];
        ax.ZColor     = [0.85 0.85 0.85];
        ax.FontSize   = 9;
        ax.Box        = 'on';
        title(ax, ...
              {'\bfDynamic AI-Tracked Parametric Acoustic Array — Live Beam Steering', ...
               sprintf('Target: (%.3f,  %.3f,  %.3f) m  |  f = %.0f kHz  |  \\lambda = %.2f mm  |  N = %d  |  −15 dB lobe', ...
                       x_t, y_t, z_t, f/1e3, lambda*1e3, num_elements)}, ...
              'FontSize',   10.5, ...
              'FontWeight', 'bold', ...
              'Color',      [0.96 0.96 0.96]);
        hold(ax, 'off');
        
        drawnow;
    end   
end