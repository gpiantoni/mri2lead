function bnd2lead(cfg, subj)
%VOL2LEAD create leadfield, based on volume
%
% CFG
%  .data: name of projects/PROJNAME/subjects/
%  .rec: name of the recordings (part of the structrual filename)
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%
%  .sens.file: file with EEG sensors. It can be sfp or mat.
%
%  .vol.type: method for head model ('bem_dipoli' 'bem_openmeeg' 'bemcp')
%  .bnd2lead.conductivity: conductivity of tissues ([0.3300 0.0042 0.3300])
%
%  .bnd2lead.mni.warp: warp or use precomputed grid (logical)
%  .bnd2lead.mni.resolution: (if warp) resolution of the grid (5,6,8,10 mm)
%  .bnd2lead.mni.nonlinear: run non-linear mni registration ('yes' or 'no')
%
%  It only makes sense to warp to mni if your MRI are not already realigned
%  in MNI space. The MNI wrapping creates a MNI-aligned grid in subject-MRI
%  space.
%
% Part of MRI2LEAD
% see also CPMRI, MRI2BND, BND2LEAD, USETEMPLATE

% load /data1/toolbox/elecloc/easycap_61_FT.mat elec
% sens = [];
% sens.elecpos = [elec.pnt; 0 0 0; 0 0 0; 0 0 0];
% sens.chanpos = [elec.pnt; 0 0 0; 0 0 0; 0 0 0];
% sens.label = elec.label;
% sens.unit = 'mm';
%
% cfg = [];
% cfg.template.vol = vol;
% cfg.individual.elec = sens;
% [cfg] = ft_interactiverealign(cfg)

%---------------------------%
%-start log
output = sprintf('(p%02.f) %s started at %s on %s\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
mdir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.vol.mod, cfg.vol.cond); % mridata dir
mfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.vol.mod, cfg.vol.cond); % mridata
ext = '.nii.gz';

bndfile = [mdir mfile '_bnd'];
volfile = [mdir mfile '_vol_' cfg.vol.type];
leadfile = [mdir mfile '_lead_' cfg.vol.type];
elecfile = [mdir mfile '_elec'];
%---------------------------%

%-------------------------------------%
%-load vol
if exist([bndfile '.mat'], 'file')
  load(bndfile, 'bnd')
else
  output = sprintf('%sBND file %s does not exist\n', output, bndfile);
end

%-----------------%
%-headmodel
try
  cfg3  = [];
  cfg3.method = cfg.vol.type;
  cfg3.conductivity = cfg.bnd2lead.conductivity;
  vol = ft_prepare_headmodel(cfg3, bnd);
end
%-----------------%
%-------------------------------------%

%-------------------------------------%
%-electrodes and leadfield
if exist('vol', 'var') && isfield(vol, 'mat')
  
  %-----------------%
  %-save vol only, if successful
  save(volfile, 'vol')
  %-----------------%
  
  %-----------------%
  %-create grid
  cfg4 = [];
  
  if cfg.bnd2lead.mni.warp
    
    if ~strcmp(cfg.normalize, '')
      output = sprintf('%ERROR: you should use the MRI in native space, not after normalization\n', outout);
    end
    
    mrifile = [mdir mfile ext]; % mri in native space, not in MNI space!
    
    mri = ft_read_mri(mrifile);
    cfg4.grid.warpmni    = 'yes';
    cfg4.grid.resolution = cfg.bnd2lead.mni.resolution;
    cfg4.grid.nonlinear  = cfg.bnd2lead.mni.nonlinear;
    cfg4.mri             = mri;
    cfg4.mri.coordsys    = 'spm';
    
  else
    
    cfg4.grid.xgrid =  -70:10:70;
    cfg4.grid.ygrid = -110:10:80;
    cfg4.grid.zgrid =  -60:10:90;
    
  end
  
  grid = ft_prepare_sourcemodel(cfg4);
  grid = ft_convert_units(grid, 'mm');
  %-----------------%
  
  %-----------------%
  %-elec
  elec = ft_read_sens(cfg.sens.file);
  elec.label = upper(elec.label);
  elec = ft_convert_units(elec, 'mm');
  
  %-------%
  %-from sens space to MNI space (based on visual realignment)
  % values can be improved and hard-coded
  elec.chanpos = warp_apply(cfg.bnd2lead.elecM, elec.chanpos);
  elec.elecpos = warp_apply(cfg.bnd2lead.elecM, elec.elecpos);
  %-------%
  %-----------------%
  
  if cfg.bnd2lead.mni.warp
    %-----------------%
    %-conversion MNI to subject space
    %-------%
    %-get realignment from subject-space to MNI space
    % The ideal solution is to use ft_volumenormalise. However, the
    % transformation matrix was completely wrong. So, we read the
    % transformation matrix from cpmri with option '_spm'. In this case,
    % however, we use the raw MRI
    outsn = [mdir mfile '_sn.mat']; % transformation from subject to MNI space
    if ~exist(outsn, 'file')
      output = sprintf(['%sERROR: you should run once ''cpmri'' with option cfg.normalize = ''_spm'', which creates a transformation matrix\n' ...
        'then, run ''mri2bnd'' and ''bnd2lead'', with cfg.normalize = ''''\nNo transformation applied, check results!!!!\n'], output);
    end
    load(outsn)
    struct2mni = VG.mat / Affine / VF.mat;
    mni2struct = inv(struct2mni);
    %-------%
    
    %-------%
    %-from sens space to MNI space (based on visual realignment)
    % values can be improved and hard-coded
    elec.chanpos = warp_apply(mni2struct, elec.chanpos);
    elec.elecpos = warp_apply(mni2struct, elec.elecpos);
    %-------%
    %-----------------%
  end
  
  %-----------------%
  %-prepare elec and vol
  [vol, elec] = ft_prepare_vol_sens(vol, elec);
  save(elecfile, 'elec')
  %-----------------%
  
  %-----------------%
  %-prepare leadfield
  cfg5 = [];
  cfg5.elec = elec;
  cfg5.vol = vol;
  cfg5.grid = grid;
  cfg5.inwardshift = cfg.bnd2lead.inwardshift; % to avoid dipoles on the border of bnd(3), which are very instable
  cfg5.grid.tight = 'no';
  cfg5.feedback = 'none';
  lead = ft_prepare_leadfield(cfg5, []);
  save(leadfile, 'lead')
  %-----------------%
  
else
  
  %-----------------%
  output = sprintf('%sft_prepare_headmodel could not create a head model!\n', output);
  %-----------------%
  
end
%-------------------------------------%

%---------------------------%
%-end log
toc_t = toc(tic_t);
outtmp = sprintf('(p%02.f) %s ended at %s on %s after %s\n\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([cfg.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%
