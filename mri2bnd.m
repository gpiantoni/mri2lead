function mri2bnd(cfg, subj)
%MRI2BND create volume, based on MRI
%
% CFG
%  .data: name of projects/PROJNAME/subjects/
%  .rec: name of the recordings (part of the structrual filename)
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%
%  .mri2bnd.tpmthreshold: threshold for segmentation (1 default, 0.05 pretty sensitive)
%  .mri2bnd.numvertices: number of vertices ([2500 1200 1000])
%  .mri2bnd.threshbnd: threshold for mesh
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
mdir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.vol.mod, cfg.vol.cond); % mridata dir
mfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.vol.mod, cfg.vol.cond); % mridata
ext = '.nii.gz';

mrifile = [mdir mfile cfg.normalize ext];
bndfile = [mdir mfile '_bnd'];
%---------------------------%

%---------------------------%
%-defaults
if ~isfield(cfg, 'mri2bnd'); cfg.mri2bnd = []; end

if ~isfield(cfg.mri2bnd, 'scalp'); cfg.mri2bnd.scalp = []; end
if ~isfield(cfg.mri2bnd.scalp, 'smooth'); cfg.mri2bnd.scalp.smooth = 5; end
if ~isfield(cfg.mri2bnd.scalp, 'threshold'); cfg.mri2bnd.scalp.threshold = 0.1; end
if ~isfield(cfg.mri2bnd.scalp, 'numvertices'); cfg.mri2bnd.scalp.numvertices = 2500; end

if ~isfield(cfg.mri2bnd, 'skull'); cfg.mri2bnd.skull = []; end
if ~isfield(cfg.mri2bnd.skull, 'smooth'); cfg.mri2bnd.skull.smooth = 5; end
if ~isfield(cfg.mri2bnd.skull, 'threshold'); cfg.mri2bnd.skull.threshold = .5; end
if ~isfield(cfg.mri2bnd.skull, 'numvertices'); cfg.mri2bnd.skull.numvertices = 2500; end

if ~isfield(cfg.mri2bnd, 'brain'); cfg.mri2bnd.brain = []; end
if ~isfield(cfg.mri2bnd.brain, 'smooth'); cfg.mri2bnd.brain.smooth = 5; end
if ~isfield(cfg.mri2bnd.brain, 'threshold'); cfg.mri2bnd.brain.threshold = .5; end
if ~isfield(cfg.mri2bnd.brain, 'numvertices'); cfg.mri2bnd.brain.numvertices = 2500; end
%---------------------------%

%-------------------------------------%
%-read and prepare mri
if exist(mrifile, 'file')
  
  %-----------------%
  %-read
  mri = ft_read_mri(mrifile);
  %-----------------%
  
  %-----------------%
  %-segmenting the volume, Tissue Probability Maps
  tmpcfg = [];
  tmpcfg.threshold  = [];
  tmpcfg.output = 'tpm';
  tmpcfg.coordsys = 'spm';
  tpm = ft_volumesegment(tmpcfg, mri);
  tpm.anatomy = mri.anatomy;
  %-----------------%
  
  %-----------------%
  %-segmenting the volume
  % the same function is repeated bc atm ft_volumesegment does not accept
  % different threshold and smoothing values
  tmpcfg = [];
  tmpcfg.coordsys = 'spm';
  
  tmpcfg.threshold  = cfg.mri2bnd.scalp.threshold;
  tmpcfg.smooth = cfg.mri2bnd.scalp.smooth;
  tmpcfg.output = 'scalp';
  segscalp = ft_volumesegment(tmpcfg, tpm);
  
  tmpcfg.threshold  = cfg.mri2bnd.skull.threshold;
  tmpcfg.smooth = cfg.mri2bnd.skull.smooth;
  tmpcfg.output = 'skull';
  segskull = ft_volumesegment(tmpcfg, tpm);

  tmpcfg.threshold  = cfg.mri2bnd.brain.threshold;
  tmpcfg.smooth = cfg.mri2bnd.brain.smooth;
  tmpcfg.output = 'brain';
  segment = ft_volumesegment(tmpcfg, tpm);
  
  segment.scalp = segscalp.scalp;
  segment.skull = segskull.skull;
 
  clear segscalp segskull
  %-----------------%
  %-------------------------------------%
  
  %-------------------------------------%
  %-mesh and headmodel
  %-----------------%
  %-prepare mesh
  tmpcfg = [];
  tmpcfg.transform = segment.transform;
  
  tmpcfg.tissue = {'scalp' 'skull' 'brain'};
  tmpcfg.numvertices = [cfg.mri2bnd.scalp.numvertices cfg.mri2bnd.skull.numvertices cfg.mri2bnd.brain.numvertices];
  
  bnd = ft_prepare_mesh(tmpcfg, segment);
  
  save(bndfile, 'bnd')
  %-----------------%
  
else
  
  %-----------------%
  output = sprintf('%sMRI file %s does not exist\n', output, mrifile);
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
fid = fopen([cfg.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%