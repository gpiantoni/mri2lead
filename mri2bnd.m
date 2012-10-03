function mri2bnd(info, opt, subj)
%MRI2BND create mesh based on MRI using fieldtrip segmentation
%
% INFO
%  .data: path of /data1/projects/PROJ/subjects/
%  .rec: REC in /data1/projects/PROJ/recordings/REC/
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%  .log: name of the file and directory to save log
%
% CFG.OPT
%  .normalize*: normalization ('none' 'spm8' 'flirt')
%  .scalp.smooth: smoothing kernel for scalp (5 cm)
%  .scalp.threshold: threshold of tpm for scalp (0.1)
%  .scalp.numvertices: # vertices for scalp (2500)
%  .skull.smooth: smoothing kernel for skull (5 cm)
%  .skull.threshold: threshold of tpm for skull (0.5)
%  .skull.numvertices: # vertices for skull (2500)
%  .brain.smooth: smoothing kernel for brain (5 cm)
%  .brain.threshold: threshold of tpm for brain (0.5)
%  .brain.numvertices: # vertices for brain (2500)
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

if strcmp(opt.normalize, 'none')
  mrifile = [mdir mfile ext];
else
  mrifile = [mdir mfile '_' opt.normalize ext];
end
bndfile = [mdir mfile '_bnd'];
%---------------------------%

%---------------------------%
%-defaults
if ~isfield(opt, 'scalp'); opt.scalp = []; end
if ~isfield(opt.scalp, 'smooth'); opt.scalp.smooth = 5; end
if ~isfield(opt.scalp, 'threshold'); opt.scalp.threshold = 0.1; end
if ~isfield(opt.scalp, 'numvertices'); opt.scalp.numvertices = 2500; end

if ~isfield(opt, 'skull'); opt.skull = []; end
if ~isfield(opt.skull, 'smooth'); opt.skull.smooth = 5; end
if ~isfield(opt.skull, 'threshold'); opt.skull.threshold = .5; end
if ~isfield(opt.skull, 'numvertices'); opt.skull.numvertices = 2500; end

if ~isfield(opt, 'brain'); opt.brain = []; end
if ~isfield(opt.brain, 'smooth'); opt.brain.smooth = 5; end
if ~isfield(opt.brain, 'threshold'); opt.brain.threshold = .5; end
if ~isfield(opt.brain, 'numvertices'); opt.brain.numvertices = 2500; end
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
  cfg = [];
  cfg.threshold  = [];
  cfg.output = 'tpm';
  cfg.coordsys = 'spm';
  tpm = ft_volumesegment(cfg, mri);
  tpm.anatomy = mri.anatomy;
  %-----------------%
  
  %-----------------%
  %-segmenting the volume
  % the same function is repeated bc atm ft_volumesegment does not accept
  % different threshold and smoothing values
  cfg = [];
  cfg.coordsys = 'spm';
  
  cfg.threshold  = opt.scalp.threshold;
  cfg.smooth = opt.scalp.smooth;
  cfg.output = 'scalp';
  segscalp = ft_volumesegment(cfg, tpm);
  
  cfg.threshold  = opt.skull.threshold;
  cfg.smooth = opt.skull.smooth;
  cfg.output = 'skull';
  segskull = ft_volumesegment(cfg, tpm);

  cfg.threshold  = opt.brain.threshold;
  cfg.smooth = opt.brain.smooth;
  cfg.output = 'brain';
  segment = ft_volumesegment(cfg, tpm);
  
  segment.scalp = segscalp.scalp;
  segment.skull = segskull.skull;
 
  clear segscalp segskull
  %-----------------%
  %-------------------------------------%
  
  %-------------------------------------%
  %-mesh and headmodel
  %-----------------%
  %-prepare mesh
  cfg = [];
  cfg.transform = segment.transform;
  
  cfg.tissue = {'scalp' 'skull' 'brain'};
  cfg.numvertices = [opt.scalp.numvertices opt.skull.numvertices opt.brain.numvertices];
  
  bnd = ft_prepare_mesh(cfg, segment);
  
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
fid = fopen([info.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%