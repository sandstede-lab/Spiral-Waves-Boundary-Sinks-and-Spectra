function [F,J] = Karma_boundary_sink(w,par,numPar,mesh_params)
% Solve the Rossler model on a half-infinite channel 


global U0;

% Rename parameters
L1y = mesh_params.DT;
L2x = mesh_params.D2Z;
nt = mesh_params.nt;
nz = mesh_params.nz; nz_long = mesh_params.nz_long;
L2X_long = mesh_params.L2X_long;

wU = w(1:nt*nz);
wV = w(nt*nz+1:2*nz*nt);
Tperiod = w(end);

tauE = 1/par.tauE;
taun = 1/par.taun;
gamma = par.gamma;
delta = par.delta;
R = 1/(1 - exp(-par.Re));

par.omega = 2*pi/Tperiod;
[u_ff0,U0,Du_ff,~] = get_karma_rolls(U0,par,numPar,mesh_params,mesh_params.Dt,mesh_params.Dt2);  
u_ff = u_ff0(1:nt*nz_long); v_ff = u_ff0(nt*nz_long+1:2*nt*nz_long);

dt = -2*pi./Tperiod; % Temporal scaling
dL = (par.kappa./(2*pi*mesh_params.N))^2;

% Reaction terms
fU = @(u,v) tauE .* ( -u + 0.5*(par.Estar - v.^par.M).*(1 - tanh(u-par.Eh)) .* u.^2 );
fV = @(u,v) taun .* ( R.* 0.5.*(1 + tanh(par.s.*(u - par.En))) - v);

D2u = dL*L2X_long * (mesh_params.chi_ffLong.*u_ff); D2u = D2u(mesh_params.bc_idx);
D2v = dL*L2X_long * (mesh_params.chi_ffLong.*v_ff); D2v = D2v(mesh_params.bc_idx);

u_ff_short = mesh_params.chi_ff.*u_ff(mesh_params.bc_idx);
v_ff_short = mesh_params.chi_ff.*v_ff(mesh_params.bc_idx);
Du_ff= mesh_params.chi_ff.*Du_ff(mesh_params.bc_idx);
 
line1 = dt.*L1y*(u_ff_short + wU) + gamma.*D2u + gamma.* (dL*L2x * wU) + fU(u_ff_short + wU, v_ff_short + wV); 
line2 = dt.*L1y*(v_ff_short + wV) + delta.*D2v + delta.* (dL*L2x * wV) + fV(u_ff_short + wU, v_ff_short + wV);

line1(mesh_params.iend) = wU(mesh_params.iend); % dirchlet bcs at the LHS of the domain for w
line2(mesh_params.iend) = wV(mesh_params.iend);

% Phase condition
L_cut = 1/mesh_params.N; 
iBm = find( mesh_params.xx(:) <= L_cut ); % find indices close to the end of 1 roll

z = linspace(0,mesh_params.Lz,mesh_params.nz);  hz= z(2) - z(1);
iim= find(z <= L_cut); nnzm = length(iim);

wz = [1, 2*ones(1,nnzm-2)+2*mod([1:nnzm-2],2),1]*hz/3;   % Simpson weights for intergration int = w*u
wt = 2*mesh_params.Lt*ones(mesh_params.nt,1)/mesh_params.nt;
wwm= kron(wz,wt');
wwm= wwm(:)';
  
wBm = wU(iBm);                       % find w on the domain x = 0:2*pi/kappa and y = 0..Ly
u_prime = Du_ff(iBm);
line3 = wwm*(u_prime .* wBm);

F = [line1; line2; line3]; 

% Jacobain
if nargout > 1
        
    fE_E = @(u,v) tauE*(-1 - 0.5.*(par.Estar - v.^par.M).*(sech(par.Eh - u).^2).* (u.^2) + (par.Estar - v.^par.M).*(1 - tanh(u - par.Eh)).*u);
    fE_n = @(u,v) tauE*(-0.5* par.M.*v.^(par.M-1) .* (1 - tanh(u - par.Eh)).*(u.^2));
    fn_E = @(u,v) taun*(R.*0.5 .* par.s .* (sech(par.s.*(u - par.En)).^2));
    fn_n = -taun;
    
    
    I = speye(nt*nz,nt*nz);
    
    phase_jacob = zeros(1,nz*nt);
    phase_jacob(iBm) = wwm*spdiags(u_prime,0,nnzm*mesh_params.nt,nnzm*mesh_params.nt);
    
     dwU = [dt.*L1y + gamma.*dL*L2x + spdiags(fE_E(u_ff_short + wU,v_ff_short+wV),0,nz*nt,nz*nt);
         spdiags(fn_E(u_ff_short+wU, v_ff_short + wV),0,nz*nt,nz*nt);
         phase_jacob];

     dwV = [spdiags(fE_n(u_ff_short + wU,v_ff_short+wV),0,nz*nt,nz*nt);
         dt.*L1y + delta.*dL*L2x + fn_n.*I;
         sparse(1,nz*nt)];   
     
     epsiF = 1e-8;
     dF = Karma_boundary_sink([w(1:end-1); w(end)+epsiF],par,numPar,mesh_params);
     dT = (dF - F)./epsiF;  
   
     J = [dwU, dwV, dT];
   
     % Boundary conditions in Jacobian
     J(mesh_params.iend,:) = 0; J(nz*nt+mesh_params.iend, :) = 0; 
     J(mesh_params.iend,mesh_params.iend)=speye(length(mesh_params.iend));
     J(nz*nt+mesh_params.iend, nz*nt+mesh_params.iend)=speye(length(mesh_params.iend));    
     
     J = sparse(J);
     
end







