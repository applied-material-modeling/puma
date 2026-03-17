SetFactory("OpenCASCADE");
// Input ----------------------------------------------------------------

n_core = 20;
n_edge = 20;
x_core = 10; //cm
core_elsize = x_core/n_core;

circle_center_x = 4;
circle_center_y = 5;
radius = 2;

//  core part -----------------------------------------------------------

o_sqrt2 = 0.7071067812;

// point for the outer rectangle
Point(1) = {0.0, 0.0, 0.0, core_elsize};
Point(2) = {x_core, 0, 0, core_elsize};
Point(3) = {x_core, x_core, 0, core_elsize};
Point(4) = {0, x_core, 0, core_elsize};

Line(12) = {1, 2}; Transfinite Curve{12} = n_core;
Line(23) = {2, 3}; Transfinite Curve{23} = n_core;
Line(34) = {3, 4}; Transfinite Curve{34} = n_core;
Line(41) = {4, 1}; Transfinite Curve{41} = n_core;

// point for the inner circle
Point(5) = {-o_sqrt2*radius + circle_center_x, -o_sqrt2*radius  + circle_center_y, 0.0, core_elsize};
Point(6) = {o_sqrt2*radius  + circle_center_x,  -o_sqrt2*radius + circle_center_y, 0.0, core_elsize};
Point(7) = {o_sqrt2*radius  + circle_center_x,  o_sqrt2*radius  + circle_center_y,  0.0, core_elsize};
Point(8) = {-o_sqrt2*radius + circle_center_x, o_sqrt2*radius   + circle_center_y,  0.0, core_elsize};
Point(9) = {circle_center_x, circle_center_y, 0.0, core_elsize};

// transition line
Line(15) = {1, 5}; Transfinite Curve{15} = n_edge;
Line(26) = {2, 6}; Transfinite Curve{26} = n_edge;
Line(37) = {3, 7}; Transfinite Curve{37} = n_edge;
Line(48) = {4, 8}; Transfinite Curve{48} = n_edge;

// connect them
Circle(56) = {5, 9, 6}; Transfinite Curve{56} = n_core;
Circle(67) = {6, 9, 7}; Transfinite Curve{67} = n_core;
Circle(78) = {7, 9, 8}; Transfinite Curve{78} = n_core;
Circle(85) = {8, 9, 5}; Transfinite Curve{85} = n_core;

// form the Loop
Curve Loop(1) = {15, 56, -26, -12}; Plane Surface(1) = {1}; Transfinite Surface{1} = {1, 5, 6, 2};
Curve Loop(2) = {26, 67, -37, -23}; Plane Surface(2) = {2}; Transfinite Surface{2} = {2, 6, 7, 3};
Curve Loop(3) = {37, 78, -48, -34}; Plane Surface(3) = {3}; Transfinite Surface{3} = {3, 7, 8, 4};
Curve Loop(4) = {48, 85, -15, -41}; Plane Surface(4) = {4}; Transfinite Surface{4} = {4, 8, 5, 1};
Curve Loop(5) = {56, 67, 78, 85}; Plane Surface(5) = {5}; // Transfinite Surface{5} = {5, 6, 7, 8};

Recombine Surface{1:5};

// Assign physical groups ------------------------------------------------
Physical Surface("non_circle") = {1:4};
Physical Surface("circle") = {5};
 
Physical Curve("core_bottom") = {12};
 
Mesh 2;
Save "core.msh";
