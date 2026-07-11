%  DESCRIPTION:
%    This script implements the core signal processing logic of the project.
%    It simulates a target moving through 3D space above the transducer array,
%    converts the target's position into acoustic steering angles (azimuth and
%    elevation), and computes per-element complex phase weights using the
%    Delay-and-Sum (DAS) beamforming principle — all without any toolbox.
%
%  PREREQUISITES (must exist in workspace from Step 1):
%    - lambda        : wavelength [m]
%    - array_coords  : 100x3 matrix of transducer [x, y, z] positions [m]
%    - c             : speed of sound [m/s]
%    - f             : carrier frequency [Hz]
%    - N             : elements per side (10)
%    - num_elements  : total elements (100)
%
%  OUTPUTS PRODUCED BY THIS SCRIPT:
%    - target_x, target_y, target_z : target trajectory vectors (1 x num_time_steps)
%    - theta_deg, phi_deg           : azimuth and elevation at each time step
%    - steering_weights             : complex weight matrix (100 x num_time_steps)
%
%  NOTE: Uses ONLY core MATLAB math. No Phased Array Toolbox.
% =========================================================================

% Workspace guard — alert the user if Step 1 variables are missing
if ~exist('lambda', 'var') || ~exist('array_coords', 'var')
    error(['Step 2 requires Step 1 variables in the workspace.\n', ...
           'Please run upa_geometry_init.m first before this script.']);
end

fprintf('\n============================================================\n');
fprintf('  STEP 2: TARGET SIMULATION & DAS BEAMFORMING\n');
fprintf('============================================================\n\n');


%% =========================================================================
%  SECTION 1: MOVING TARGET SIMULATION
%  -------------------------------------------------------------------------
%  We model a single point target (e.g. a person walking) moving through
%  3D space at a fixed height of 2 metres above the array plane (z = 0).
%
%  Physical Setup:
%    - The transducer array lies flat on the XY plane (z = 0).
%    - The array "looks" upward in the +Z direction.
%    - The target moves in the XY plane at fixed height z = 2.0 m.
%    - Trajectory: a straight diagonal path from (-1.5, -1.5) to (+1.5, +1.5).
%      This crosses all four steering quadrants: starting at negative azimuth
%      and ending at positive azimuth, providing a rich test of the
%      beamformer's angular tracking range.
% =========================================================================

% --- Time Vector ---
%   50 discrete time snapshots over a 5-second interval.
%   Each snapshot corresponds to one "look direction" for the beamformer.
num_time_steps = 50;
t = linspace(0, 5, num_time_steps);  
target_z_height = 2.0;
target_x = linspace(-1.5, 1.5, num_time_steps);  
target_y = linspace(-1.5, 1.5, num_time_steps); 
target_z = target_z_height * ones(1, num_time_steps); 
fprintf('  TARGET TRAJECTORY\n');
fprintf('  ----------------------------------------------------------\n');
fprintf('  Start position     : (%.2f, %.2f, %.2f) m\n', target_x(1),   target_y(1),   target_z(1));
fprintf('  End   position     : (%.2f, %.2f, %.2f) m\n', target_x(end), target_y(end), target_z(end));
fprintf('  Fixed height       : %.2f m\n', target_z_height);
fprintf('  Time span          : %.1f s  (%d snapshots)\n', t(end), num_time_steps);
fprintf('  Snapshot interval  : %.4f s  (%.1f ms)\n\n', t(2)-t(1), (t(2)-t(1))*1e3);


%  SECTION 2: COORDINATE-TO-STEERING ANGLE CONVERSION

theta_rad = zeros(1, num_time_steps);   
phi_rad   = zeros(1, num_time_steps); 

for i = 1:num_time_steps
    x_t = target_x(i);  
    y_t = target_y(i);  
    z_t = target_z(i);   
    theta_rad(i) = atan2(y_t, x_t);
    horiz_range   = sqrt(x_t^2 + y_t^2);
    phi_rad(i)    = atan2(z_t, horiz_range);

end
theta_deg = rad2deg(theta_rad); 
phi_deg   = rad2deg(phi_rad);  

% Display angle range summary
fprintf('  STEERING ANGLE SUMMARY\n');
fprintf('  ----------------------------------------------------------\n');
fprintf('  Azimuth   theta : [%.2f, %.2f] deg\n', min(theta_deg), max(theta_deg));
fprintf('  Elevation phi   : [%.2f, %.2f] deg\n', min(phi_deg),   max(phi_deg));
fprintf('  (Angles computed using atan2 for full quadrant resolution)\n\n');
k = 2 * pi / lambda;   

fprintf('  BEAMFORMING PARAMETERS\n');
fprintf('  ----------------------------------------------------------\n');
fprintf('  Wave number  k = 2*pi/lambda = %.4f rad/m\n\n', k);
steering_weights = complex(zeros(num_elements, num_time_steps));   
fprintf('  Computing steering weights for %d time steps...\n', num_time_steps);

for i = 1:num_time_steps
    x_t = target_x(i);
    y_t = target_y(i);
    z_t = target_z(i);


    r_vec = [x_t, y_t, z_t];       
    r_hat = r_vec / norm(r_vec);   
    k_vec = k * r_hat;
    phase_shift = array_coords * k_vec.';
w_n = exp(-1j * phase_shift);
    steering_weights(:, i) = w_n;

end

fprintf('  Done. Steering weight matrix size: %d elements x %d time steps.\n', ...
        size(steering_weights, 1), size(steering_weights, 2));
fprintf('  All weights are unit-magnitude phasors (|w_n| = 1 for all n,t).\n');
fprintf('  Weight magnitude check: mean = %.6f (expected 1.0)\n\n', ...
        mean(abs(steering_weights(:))));

%  SECTION 4: DYNAMIC 3D VISUALIZATION — ANIMATED BEAM TRACKING
fprintf('  Launching dynamic 3D tracking animation...\n');
fprintf('  (Animation: %d frames, 0.1 s pause per frame)\n\n', num_time_steps);
fig = figure('Name', 'Dynamic Beam Tracking — Target Trajectory & Line of Sight', ...
             'NumberTitle', 'off', ...
             'Color', [0.10 0.10 0.12], ...    
             'Position', [80, 80, 1000, 720]);

% =========== STATIC ELEMENTS (drawn once before the animation loop) ===========
scatter3(array_coords(:,1), array_coords(:,2), array_coords(:,3), ...
         40, 'filled', ...
         'MarkerFaceColor', [0.30 0.65 0.90], ...  
         'MarkerEdgeColor', [0.10 0.35 0.60]);
hold on;
plot3(target_x, target_y, target_z, ...
      '--', ...
      'Color',     [0.85 0.85 0.85], ... 
      'LineWidth',  1.2);
scatter3(0, 0, 0, 80, 'filled', ...
         'MarkerFaceColor', [0.0 1.0 0.85], ...
         'MarkerEdgeColor', [0.0 0.6 0.5]);
text(0, 0, 0.15, '  Array Origin', ...
     'Color', [0.0 1.0 0.85], 'FontSize', 8, 'FontWeight', 'bold');
grid on;
xlabel('X  (meters)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.9 0.9 0.9]);
ylabel('Y  (meters)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.9 0.9 0.9]);
zlabel('Z  (meters)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.9 0.9 0.9]);
axis equal;
xlim([-2.2  2.2]);
ylim([-2.2  2.2]);
zlim([-0.3  2.6]);
view(35, 22); 
ax = gca;
ax.Color         = [0.10 0.10 0.12];
ax.GridColor     = [0.45 0.45 0.45];
ax.GridAlpha     = 0.35;
ax.XColor        = [0.80 0.80 0.80];
ax.YColor        = [0.80 0.80 0.80];
ax.ZColor        = [0.80 0.80 0.80];
ax.FontSize      = 9;
ax.Box           = 'on';
legend({'Transducer Array (100 elements)', ...
        'Full Target Path', ...
        'Array Origin (0,0,0)'}, ...
       'TextColor', [0.9 0.9 0.9], ...
       'Color',     [0.18 0.18 0.20], ...
       'EdgeColor', [0.45 0.45 0.45], ...
       'Location',  'northwest', ...
       'FontSize',   8);
% =========== INITIALIZE DYNAMIC GRAPHICS OBJECTS ===========
h_target = scatter3(target_x(1), target_y(1), target_z(1), ...
                    120, 'filled', ...
                    'MarkerFaceColor', [1.0 0.25 0.25], ...   % Bright red
                    'MarkerEdgeColor', [0.8 0.0  0.0]);
h_los = plot3([0, target_x(1)], [0, target_y(1)], [0, target_z(1)], ...
              '-', ...
              'Color',     [1.0 0.85 0.1], ...   
              'LineWidth',  1.8);

% =========== ANIMATION LOOP ===========
for i = 1:num_time_steps

    x_t    = target_x(i);
    y_t    = target_y(i);
    z_t    = target_z(i);
    az_deg = theta_deg(i);
    el_deg = phi_deg(i);
    set(h_target, 'XData', x_t, 'YData', y_t, 'ZData', z_t);
    set(h_los, 'XData', [0, x_t], 'YData', [0, y_t], 'ZData', [0, z_t]);
    title({sprintf('Dynamic AI-Tracked Parametric Array — Beam Steering Simulation'), ...
           sprintf('t = %.2f s  |  Target: (%.3f, %.3f, %.3f) m  |  \\theta = %.1f\\circ  |  \\phi = %.1f\\circ', ...
                   t(i), x_t, y_t, z_t, az_deg, el_deg)}, ...
          'FontSize', 10.5, 'FontWeight', 'bold', 'Color', [0.95 0.95 0.95]);
    drawnow;
    pause(0.1);

end

fprintf('  Animation complete.\n');
fprintf('============================================================\n');
fprintf('  STEP 2 COMPLETE — Steering weight matrix is in workspace.\n');
fprintf('  steering_weights : %d x %d complex matrix\n', ...
        size(steering_weights,1), size(steering_weights,2));
fprintf('============================================================\n');
