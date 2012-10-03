function bnd2lead(info, opt, subj)
%BND2LEAD create leadfield
%
% INFO
%  .data: path of /data1/projects/PROJ/subjects/
%  .rec: REC in /data1/projects/PROJ/recordings/REC/
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%  .vol.type: method for head model ('dipoli' 'openmeeg' 'bemcp')
%  .sourcespace: 'surface' or 'volume' or 'volume_warp'
%  .sens.file: file with EEG sensors. It can be sfp or mat.
%  .log: name of the file and directory to save log
%
% CFG.OPT
%  .conductivity*: conductivity of tissues ([0.3300 0.0042 0.3300])
%  .inwardshift: shift inward to exclude dipoles on the edge of mesh
%  .mni.resolution (if 'volume_warp')*: resolution of the grid (5,6,8,10 mm)
%  .mni.nonlinear (if 'volume_warp')*: run non-linear mni registration ('yes' or 'no')
%  .elecM: 4x4 affine matrix of the transformation of the electrodes
%
%  It only makes sense to warp to mni if your MRI are not already realigned
%  in MNI space. The MNI wrapping creates a MNI-aligned grid in subject-MRI
%  space.
%
% * indicates obligatory parameter
%
% Part of MRI2LEAD
% see also CPMRI, MRI2BND, FREESURFER2BND, BND2LEAD, USETEMPLATE

%---------------------------%
%-start log
output = sprintf('%s (%04d) began at %s on %s\n', ...
  mfilename, subj, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
mdir = sprintf('%s%04d/%s/%s/', info.data, subj, info.vol.mod, info.vol.cond); % mridata dir
mfile = sprintf('%s_%04d_%s_%s', info.rec, subj, info.vol.mod, info.vol.cond); % mridata
ext = '.nii.gz';

bndfile = [mdir mfile '_bnd'];
gridfile = [mdir mfile '_grid'];
volfile = [mdir mfile '_vol_' info.vol.type];
leadfile = [mdir mfile '_lead_' info.vol.type];
elecfile = [mdir mfile '_elec'];

if ~isfield(opt, 'inwardshift'); opt.inwardshift = .5; end
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
cfg  = [];
cfg.method = info.vol.type;
cfg.conductivity = opt.conductivity;
try
  vol = AAAft_prepare_headmodel(cfg, bnd);
catch
  load(volfile)
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
  cfg = [];
  switch info.sourcespace
    
    case 'surface'
      
      load(gridfile, 'grid')
      cfg.grid = grid;
      grid = ft_prepare_sourcemodel(cfg);
  
    case 'volume'
      
      grid.xgrid =  -70:10:70;
      grid.ygrid = -110:10:80;
      grid.zgrid =  -60:10:90;
      grid.unit = 'mm';
      
    case 'volume_warp'
      mrifile = [mdir mfile ext]; % mri in native space, not in MNI space!
      mri = ft_read_mri(mrifile);
      cfg.mri = mri;
      cfg.mri.coordsys    = 'spm';

      cfg.grid.warpmni    = 'yes';
      cfg.grid.resolution = opt.mni.resolution;
      cfg.grid.nonlinear  = opt.mni.nonlinear;
      
      grid = ft_prepare_sourcemodel(cfg);

  end
  
  grid = ft_convert_units(grid, 'mm');  
  %-----------------%
  
  %-----------------%
  %-elec
  elec = ft_read_sens(info.sens.file);
  elec.label = upper(elec.label);
  elec = ft_convert_units(elec, 'mm');
  
  %-------%
  %-from sens space to MNI space (based on visual realignment)
  % values can be improved and hard-coded
  elec.chanpos = warp_apply(opt.elecM, elec.chanpos);
  elec.elecpos = warp_apply(opt.elecM, elec.elecpos);
  %-------%
  %-----------------%
  
  if strcmp(info.sourcespace, 'volume_warp')
    %-----------------%
    %-conversion MNI to subject space
    %-------%
    %-get realignment from subject-space to MNI space
    % It uses the information from ft_volumenormalise. However, it does not
    % give very reliable results. Please, double-check this option before
    % using it.
    struct2mni = grid.params.VG.mat / grid.params.Affine / grid.params.VF.mat;
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
  cfg = [];
  cfg.elec = elec;
  cfg.vol = vol;
  cfg.grid = grid;
  cfg.inwardshift = opt.inwardshift; % to avoid dipoles on the border of bnd(3), which are very instable
  cfg.grid.tight = 'no';
  cfg.feedback = 'none';
  lead = ft_prepare_leadfield(cfg, []);
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
outtmp = sprintf('%s (%04d) ended at %s on %s after %s\n\n', ...
  mfilename, subj, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([info.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%
