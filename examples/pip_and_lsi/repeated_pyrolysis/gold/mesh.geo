xmax = 1.0/10;

nx = 50;

Point(1) = {0, 0, 0};
Point(2) = {xmax, 0, 0};
Point(3) = {xmax, xmax, 0};
Point(4) = {0, xmax, 0};

Line(1) = {1, 2}; Transfinite Curve{1} = nx;
Line(2) = {2, 3}; Transfinite Curve{2} = nx;
Line(3) = {3, 4}; Transfinite Curve{3} = nx;
Line(4) = {4, 1}; Transfinite Curve{4} = nx;
Line Loop(1) = {1, 2, 3, 4};

Plane Surface(1) = {1};
Transfinite Surface{1} = {1,2,3,4};
Recombine Surface{1};

Physical Curve("open") = {1, 2, 3, 4};
// Physical Curve("left") = {4};
// Physical Curve("bottom") = {1};

Physical Surface("all") = 1;

Mesh 2;
Save "2D_plane.msh";
