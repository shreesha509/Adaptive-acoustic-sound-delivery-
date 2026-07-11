
%  DESCRIPTION:
%    This is the final stage of the simulation. It mathematically proves
%    that the phase delays computed in Step 2 (Delay-and-Sum beamforming)
%    produce a physically focused acoustic beam in 3D space.
%
%    The core computation is the WAVE SUPERPOSITION PRINCIPLE:
%      The total pressure field is the coherent sum of 100 individual
%      spherical waves, each pre-phased by the DAS steering weight w_n.
%      Where the waves arrive in phase (near the target), they add
%      constructively, forming the main beam lobe. Everywhere else,
%      the random phase relationships cause destructive cancellation.
%
%    To keep computation tractable, the pressure field is evaluated
%    only for the FINAL time step, where the beam is steered toward
%    the fully-tracked target position at (1.5, 1.5, 2.0) m.
%
%  PREREQUISITES (must exist in workspace from Steps 1 & 2):
%    - array_coords      : 100x3  transducer positions [m]
%    - steering_weights  : 100xnum_time_steps complex weight matrix
%    - k                 : wave number [rad/m]
%    - lambda            : wavelength [m]
%    - f                 : carrier frequency [Hz]
%    - num_elements      : 100
%
%  OUTPUTS PRODUCED:
%    - P_total  : 45x45x45 complex 3D pressure field
%    - P_mag    : 45x45x45 pressure magnitude
%    - SPL_dB   : 45x45x45 normalized sound pressure level [dB]
%    - Figure   : Professional dark-themed 3D beam visualization
%
%  NOTE: Uses ONLY core MATLAB functions. No Phased Array Toolbox.
% =========================================================================

% Workspace guard — confirm Step 1 & 2 variables are available
if ~exist('array_coords','var') || ~exist('steering_weights','var') || ~exist('k','var')
    error(['Step 3 requires Steps 1 & 2 variables in the workspace.\n', ...
           'Please run upa_geometry_init.m and step2_beamforming.m first.']);
end

fprintf('\n============================================================\n');
fprintf('  STEP 3: ACOUSTIC PRESSURE FIELD & 3D BEAM VISUALIZATION\n');
fprintf('============================================================\n\n');
%  SECTION 1: EXTRACT FINAL STEERING WEIGHTS & BUILD OBSERVATION GRID

w_final = steering_weights(:, end);  
target_final = [1.5, 1.5, 2.0];   % [x, y, z] in metres

grid_pts  = 45;                                     
x_obs_vec = linspace(-2.0, 2.0, grid_pts);   
y_obs_vec = linspace(-2.0, 2.0, grid_pts);        
z_obs_vec = linspace( 0.1, 2.5, grid_pts);       

[X_obs, Y_obs, Z_obs] = meshgrid(x_obs_vec, y_obs_vec, z_obs_vec);

% Display grid info
fprintf('  OBSERVATION GRID\n');
fprintf('  ----------------------------------------------------------\n');
fprintf('  Resolution         : %d x %d x %d  (%d total points)\n', ...
        grid_pts, grid_pts, grid_pts, grid_pts^3);
fprintf('  X span             : [%.1f, %.1f] m\n', x_obs_vec(1),   x_obs_vec(end));
fprintf('  Y span             : [%.1f, %.1f] m\n', y_obs_vec(1),   y_obs_vec(end));
fprintf('  Z span             : [%.1f, %.1f] m\n', z_obs_vec(1),   z_obs_vec(end));
fprintf('  Final target pos   : (%.1f, %.1f, %.1f) m\n\n', ...
        target_final(1), target_final(2), target_final(3));
fprintf('  WAVE SUPERPOSITION COMPUTATION\n');
fprintf('  ----------------------------------------------------------\n');
fprintf('  Summing spherical waves from %d transducer elements...\n', num_elements);
tic; 
for n = 1:num_elements
    xn = array_coords(n, 1);   
    yn = array_coords(n, 2);   
    zn = array_coords(n, 3);  
    R = sqrt((X_obs - xn).^2 + (Y_obs - yn).^2 + (Z_obs - zn).^2);
    R(R < 1e-4) = 1e-4;
    P_total = P_total + w_final(n) .* exp(-1j * k * R) ./ R;
end
elapsed = toc;

fprintf('  Computation complete. Time elapsed: %.2f seconds.\n', elapsed);
fprintf('  P_total size: %s  (complex 3D field)\n\n', ...
        mat2str(size(P_total)));

%  SECTION 3: ACOUSTIC INTENSITY & SOUND PRESSURE LEVEL (SPL)

far_field_mask = Z_obs > 0.5;
peak_pressure = max(P_mag(far_field_mask));

SPL_dB = 20 * log10(P_mag / peak_pressure); 
SPL_dB(SPL_dB > 0) = 0; 

noise_floor_dB = -20;
SPL_dB(SPL_dB < noise_floor_dB) = noise_floor_dB;

fprintf('  PRESSURE FIELD STATISTICS\n');
fprintf('  ----------------------------------------------------------\n');
fprintf('  Far-Field Peak used for 0 dB reference.\n');
fprintf('  SPL range after floor   : [%.1f dB,  0.0 dB]\n\n', noise_floor_dB);

%  SECTION 4: PROFESSIONAL 3D BEAM VISUALIZATION
fprintf('  Rendering 3D beam visualization figure...\n');
fig3 = figure('Name',        'Step 3 — 3D Acoustic Pressure Field & Beam Lobe', ...
              'NumberTitle', 'off', ...
              'Color',       [0.10 0.10 0.12], ...  
              'Position',    [100, 100, 1000, 700]);
hold on;
scatter3(array_coords(:,1), array_coords(:,2), array_coords(:,3), ...
         35, 'filled', ...
         'MarkerFaceColor', [0.15 0.90 0.90], ... 
         'MarkerEdgeColor', [0.05 0.55 0.55], ...   
         'DisplayName',     '100 Transducer Elements');
scatter3(target_final(1), target_final(2), target_final(3), ...
         220, 'filled', ...
         'MarkerFaceColor', [1.0  0.15 0.15], ...   % Bright red
         'MarkerEdgeColor', [0.8  0.0  0.0], ...
         'LineWidth', 1.5, ...
         'DisplayName', sprintf('Target  (%.1f, %.1f, %.1f) m', target_final));


text(target_final(1) + 0.12, target_final(2), target_final(3) + 0.10, ...
     sprintf(' Target\n (%.1f, %.1f, %.1f) m', target_final(1), target_final(2), target_final(3)), ...
     'Color',      [1.0 0.45 0.45], ...
     'FontSize',   8.5, ...
     'FontWeight', 'bold');
slice_h = slice(X_obs, Y_obs, Z_obs, SPL_dB, ...
                [0, target_final(1)], ...  
                [0, target_final(2)], ...   
                [0.5, target_final(3)]);  
shading interp;
colormap(jet);            
clim([noise_floor_dB 0]);


cb = colorbar;
cb.Color      = [0.90 0.90 0.90];    
cb.Label.String    = 'Normalized SPL  (dB re peak)';
cb.Label.Color     = [0.90 0.90 0.90];
cb.Label.FontSize  = 10;
cb.Label.FontWeight = 'bold';
iso_val = -15; 
iso_struct = isosurface(X_obs, Y_obs, Z_obs, SPL_dB, iso_val);

if ~isempty(iso_struct.vertices)
    p_iso = patch(iso_struct);
    set(p_iso, ...
        'FaceColor',  [1.0  0.92 0.1], ...  
        'EdgeColor',  'none', ...       
        'FaceAlpha',  0.40, ...            
        'DisplayName', sprintf('%d dB Beam Lobe', iso_val));
    isonormals(X_obs, Y_obs, Z_obs, SPL_dB, p_iso);
else
    warning('Isosurface at %d dB is empty — beam may not reach this level.', iso_val);
end
camlight;
lighting gouraud;
xlabel('X  (meters)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.92 0.92 0.92]);
ylabel('Y  (meters)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.92 0.92 0.92]);
zlabel('Z  (meters)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.92 0.92 0.92]);
title({'\bfDynamic AI-Tracked Parametric Acoustic Array Simulation', ...
       sprintf('3D Beam  |  Target: (%.1f, %.1f, %.1f) m  |  f = %.0f kHz  |  N = %d elements  |  %d dB lobe shown', ...
               target_final(1), target_final(2), target_final(3), ...
               f/1e3, num_elements, iso_val)}, ...
      'FontSize', 11, ...
      'FontWeight', 'bold', ...
      'Color',      [0.96 0.96 0.96]);
grid on;
axis equal;
axis tight;
view(38, 26);

ax3 = gca;
ax3.Color         = [0.10 0.10 0.12];
ax3.GridColor     = [0.50 0.50 0.50];
ax3.GridAlpha     = 0.30;
ax3.XColor        = [0.85 0.85 0.85];
ax3.YColor        = [0.85 0.85 0.85];
ax3.ZColor        = [0.85 0.85 0.85];
ax3.FontSize      = 9;
ax3.Box           = 'on';
ax3.BoxStyle      = 'full';

% ---- Legend ----
lg = legend({'100 Transducer Elements', ...
             sprintf('Target  (%.1f, %.1f, %.1f) m', target_final), ...
             sprintf('%d dB Beam Lobe', iso_val)}, ...
            'TextColor',  [0.92 0.92 0.92], ...
            'Color',      [0.16 0.16 0.18], ...
            'EdgeColor',  [0.45 0.45 0.45], ...
            'Location',   'northwest', ...
            'FontSize',   9);
hold off;

fprintf('  Figure rendered successfully.\n\n');

%% =========================================================================
%  SECTION 5: SUMMARY REPORT
%  =========================================================================
fprintf('============================================================\n');
fprintf('  STEP 3 COMPLETE — SIMULATION SUMMARY\n');
fprintf('============================================================\n');
fprintf('  Array         : %d-element 10x10 UPA  |  d = lambda/2\n',   num_elements);
fprintf('  Frequency     : %.1f kHz  |  lambda = %.4f mm\n',           f/1e3, lambda*1e3);
fprintf('  Wave number   : k = %.4f rad/m\n',                          k);
fprintf('  Beam steered  : Target (%.1f, %.1f, %.1f) m\n',             target_final);
fprintf('  Grid size     : %dx%dx%d  (%d points evaluated)\n',         grid_pts, grid_pts, grid_pts, grid_pts^3);
fprintf('  Peak SPL      : 0.0 dB  (normalized reference)\n');
fprintf('  -15 dB volume : %.2f%% of total grid  (beam lobe shown)\n', 100*sum(SPL_dB(:)>=-15)/numel(SPL_dB));
fprintf('  Noise floor   : clamped at %d dB\n',                        noise_floor_dB);
fprintf('============================================================\n');
fprintf('  Simulation pipeline complete: Steps 1 -> 2 -> 3 finished.\n');
fprintf('============================================================\n\n');