
clc;         
clear;        
close all;   



%  SECTION 1: ACOUSTIC PHYSICS SETUP
c=343;
f = 40e3;       
lambda = c / f;   
fprintf('============================================================\n');
fprintf('  ACOUSTIC PHYSICS PARAMETERS\n');
fprintf('============================================================\n');
fprintf('  Speed of sound      c      = %.1f m/s\n',  c);
fprintf('  Carrier frequency   f      = %.1f kHz\n',  f / 1e3);
fprintf('  Wavelength          lambda = %.4f m  (%.4f mm)\n', lambda, lambda * 1e3);
fprintf('============================================================\n\n');

%  SECTION 2: ARRAY DESIGN PARAMETERs
N = 10;                
num_elements = N * N;   
d = lambda / 2; 
% Display array design parameters
fprintf('============================================================\n');
fprintf('  ARRAY DESIGN PARAMETERS\n');
fprintf('============================================================\n');
fprintf('  Array layout        N      = %d x %d  (%d elements total)\n', N, N, num_elements);
fprintf('  Element spacing     d      = %.4f m  (%.4f mm)\n',  d, d * 1e3);
fprintf('  Physical aperture   A      = %.4f m  (%.2f mm) per side\n', (N-1)*d, (N-1)*d*1e3);
fprintf('============================================================\n\n');

%  SECTION 3: ELEMENT COORDINATE GENERATION (VECTORIZED)
element_positions_1D = (-(N-1)/2 : (N-1)/2) * d; 
[x_grid, y_grid] = meshgrid(element_positions_1D, element_positions_1D);

z_grid = zeros(N, N);  
x_coords = x_grid(:);  
y_coords = y_grid(:);  
z_coords = z_grid(:);

array_coords = [x_coords, y_coords, z_coords]; 

fprintf('============================================================\n');
fprintf('  COORDINATE VERIFICATION\n');
fprintf('============================================================\n');
fprintf('  Total elements generated   : %d\n',  size(array_coords, 1));
fprintf('  X range : [%.4f,  %.4f] m\n', min(x_coords), max(x_coords));
fprintf('  Y range : [%.4f,  %.4f] m\n', min(y_coords), max(y_coords));
fprintf('  Z range : [%.4f,  %.4f] m  (all zero — XY plane)\n', min(z_coords), max(z_coords));
fprintf('  Centre of array (mean x,y) : (%.6f, %.6f) m\n', mean(x_coords), mean(y_coords));
fprintf('  Verified: array is centred at the origin.\n');
fprintf('============================================================\n\n');

figure('Name', 'UPA Geometry — 10x10 Transducer Array', ...
       'NumberTitle', 'off', ...
       'Color', [0.97 0.97 0.97], ...        
       'Position', [100, 100, 860, 680]);  

scatter3(x_coords, y_coords, z_coords, ...
         60, ...                                     
         'filled', ...                          
         'MarkerFaceColor', [0.18 0.52 0.80], ... 
         'MarkerEdgeColor', [0.05 0.25 0.50], ...  
         'LineWidth', 0.8);                         
% --- Labels and Title ---
title({'10 x 10 Uniform Planar Array (UPA) — Element Positions', ...
       sprintf('f = %.0f kHz  |  lambda = %.2f mm  |  d = lambda/2 = %.2f mm  |  N = %d elements', ...
               f/1e3, lambda*1e3, d*1e3, num_elements)}, ...
      'FontSize', 13, 'FontWeight', 'bold', 'Color', [0.15 0.15 0.15]);

xlabel('X  (meters)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Y  (meters)', 'FontSize', 11, 'FontWeight', 'bold');
zlabel('Z  (meters)', 'FontSize', 11, 'FontWeight', 'bold');


grid on;      
axis equal;   
axis tight;    % Fit axis bounds tightly around data points

% Manually set Z limits so the flat (z=0) array is clearly visible.
% Without this, MATLAB may auto-scale Z to an extremely narrow range
% that makes the XY plane look like a thin line rather than a flat surface.
zlim([-0.1 0.1]);   % +/-0.1 m Z window reveals the plane clearly

view(3);       % Standard isometric 3D viewing angle

% --- Axis Object Formatting ---
ax = gca;
ax.FontSize   = 10;
ax.Color      = [0.98 0.98 0.98];   % Slightly off-white axes background
ax.GridColor  = [0.5 0.5 0.5];
ax.GridAlpha  = 0.4;
ax.Box        = 'on';

% --- Reference Plane: draw a transparent XY rectangle at z=0 ---
%   This visually reinforces that all elements lie on the same plane.
hold on;
half_span = ((N-1)/2 * d) + d * 0.5;   % Slightly larger than array extent
patch_x = [-half_span,  half_span,  half_span, -half_span];
patch_y = [-half_span, -half_span,  half_span,  half_span];
patch_z = [0, 0, 0, 0];
fill3(patch_x, patch_y, patch_z, [0.18 0.52 0.80], ...
      'FaceAlpha', 0.07, ...              % Nearly transparent
      'EdgeColor', [0.18 0.52 0.80], ...
      'EdgeAlpha', 0.3, ...
      'LineStyle', '--');

% --- Origin Marker ---
%   A red cross marks the geometric centre of the array at (0,0,0)
scatter3(0, 0, 0, 140, 'r', 'x', 'LineWidth', 2.5);
text(0, 0, 0.013, '  Origin (0,0,0)', 'FontSize', 9.5, ...
     'Color', [0.75 0.0 0.0], 'FontWeight', 'bold');

% --- Legend ---
legend({'Transducer Elements (100)', 'Array Plane  (XY, z = 0)', 'Array Centre (0,0,0)'}, ...
       'Location', 'northeast', 'FontSize', 9);

hold off;

% Final confirmation message
fprintf('  Figure rendered: 10x10 UPA element positions (3D scatter).\n');
fprintf('  Script complete. Geometry initialization successful.\n');
fprintf('============================================================\n');
