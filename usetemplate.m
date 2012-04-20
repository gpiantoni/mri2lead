function usetemplate(cfg)
%USETEMPLATE use bnd, vol, bnd and lead from template if bnd2lead failed
%
% CFG
%  .data: name of projects/PROJNAME/subjects/
%  .rec: name of the recordings (part of the structrual filename)
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%
%  .sens.file: file with EEG sensors. It can be sfp or mat.
%
%  .usetemplate.mri: filename of the mri in MNI space to be used
%
%  .vol.type: method for head model ('bem_dipoli' 'bem_openmeeg' 'bemcp')
%  .bnd2lead.conductivity: conductivity of tissues ([0.3300 0.0042 0.3300])
%
%  .bnd2lead.mni.warp: warp or use precomputed grid (logical)
%
% Part of MRI2LEAD
% see also CPMRI, MRI2BND, BND2LEAD, USETEMPLATE

%---------------------------%
%-start log
output = sprintf('%s started at %s on %s\n', ...
  mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
todosubj = false(numel(cfg.subjall),1);

for i = 1:numel(cfg.subjall)
  subj = cfg.subjall(i);
  mdir = sprintf('%s%04d/%s/%s/', cfg.data, subj, cfg.vol.mod, cfg.vol.cond); % mridata dir
  mfile = sprintf('%s_%04d_%s_%s', cfg.rec, subj, cfg.vol.mod, cfg.vol.cond); % mridata
  ext = '.nii.gz';
  volfile = [mdir mfile '_vol_' cfg.vol.type];
  
  if ~exist([volfile '.mat'], 'file')
    output = sprintf('%sVOL does not exist for subj %04d, recreate it\n', ...
      output, subj);
    todosubj(i) = true;
  end
  
end
%---------------------------%

%---------------------------%
%-recreate vol from template
if any(todosubj)
  
  mri = ft_read_mri(cfg.usetemplate.mri);
  
  %-----------------%
  %-segmenting the volume
  cfg1 = [];
  cfg1.threshold  = [];
  cfg1.output = {'scalp' 'skull' 'brain'};
  cfg1.coordsys = 'spm';
  segment = ft_volumesegment(cfg1, mri);
  %-----------------%
  
  %-----------------%
  %-prepare mesh for skull and brain (easy)
  cfg2 = [];
  cfg2.tissue = {'scalp' 'skull', 'brain'};
  cfg2.numvertices = cfg.mri2bnd.numvertices;
  cfg2.transform = segment.transform;
  bnd = ft_prepare_mesh_new(cfg2, segment);
  %-----------------%
  
  %-----------------%
  cfg1  = [];
  cfg1.method = cfg.vol.type;
  cfg1.conductivity = cfg.bnd2lead.conductivity;
  vol = ft_prepare_headmodel(cfg1, bnd);
  %-----------------%
  
  %-----------------%
  %-create grid
  if cfg.bnd2lead.mni.warp
    gridfile = sprintf('/data1/toolbox/fieldtrip/template/sourcemodel/standard_grid3d%dmm.mat', ...
      cfg.bnd2lead.mni.resolution);
    load(gridfile, 'grid')
    
  else
    
    grid.xgrid =  -70:10:70;
    grid.ygrid = -110:10:80;
    grid.zgrid =  -60:10:90;
    
  end
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
  
  %-----------------%
  %-prepare elec and vol
  [vol_elec, elec] = ft_prepare_vol_sens(vol, elec);
  %-----------------%
  
  %-----------------%
  %-prepare leadfield
  cfg5 = [];
  cfg5.elec = elec;
  cfg5.vol = vol_elec;
  cfg5.grid = grid;
  cfg5.inwardshift = cfg.bnd2lead.inwardshift; % to avoid dipoles on the border of bnd(3), which are very instable
  cfg5.grid.tight = 'no';
  cfg5.feedback = 'none';
  lead = ft_prepare_leadfield(cfg5, []);
  %-----------------%
  
else
  
  %-----------------%
  output = sprintf('%sAll subjects have good vol, not calculating vol\n', output);
  %-----------------%
  
end
%---------------------------%

%---------------------------%
%-copy vol, elec, lead into each subject
for i = find(todosubj)
  
  subj = cfg.subjall(i);
  mdir = sprintf('%s%04d/%s/%s/', cfg.data, subj, cfg.vol.mod, cfg.vol.cond); % mridata dir
  mfile = sprintf('%s_%04d_%s_%s', cfg.rec, subj, cfg.vol.mod, cfg.vol.cond); % mridata
  
  volfile = [mdir mfile '_vol_' cfg.vol.type];
  leadfile = [mdir mfile '_lead_' cfg.vol.type];
  elecfile = [mdir mfile '_elec'];
  
  save(volfile, 'vol')
  save(elecfile, 'elec')
  save(leadfile, 'lead')
  
end
%---------------------------%

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
