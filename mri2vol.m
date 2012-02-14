function mri2vol(cfg, subj)
%MRI2VOL create leadfield, based on MRI

mversion = 10;
%10 12/02/14 renamed to mri2vol
%09 12/02/05 copied from gosd/source_mri2vol, but don't do extrasmoothing
%08 12/02/03 prepare leadfield again, it does depend on n of elec, but we can remove extra electrodes
%07 12/01/12 include name of the volume
%06 11/11/30 don't prepare lead field, do it on the fly (depends on n of elec)
%05 11/11/17 very liberal threshold and smoothing, some subjects are pretty bad [5 8 12 13 15]
%04 11/11/16 use normalized images (spm or flirt)
%03 11/11/16 lower threshold for scalp 0.05
%02 11/11/11 mesh new
%01 11/11/10 created

%-----------------%
%-input
if nargin == 1
  subj = cfg.subj;
end
%-----------------%

%---------------------------%
%-start log
output = sprintf('(p%02.f) %s (v%02.f) started at %s on %s\n', ...
  subj, mfilename,  mversion, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
ddir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.mod, cfg.cond); % data

dfile = sprintf('%s_%s_%04.f_%s_%s', cfg.proj, cfg.rec, subj, cfg.mod, cfg.cond); % data

mrifile = [ddir dfile '_' cfg.normalize '.nii.gz'];

%-maybe it's better to give different names for different subjects, such as
% bnd_001, bnd_002, but not at the moment
bndfile = [ddir dfile '_bnd'];
volfile = [ddir dfile '_vol' cfg.mri2vol.method(4:end)];
%---------------------------%

%-------------------------------------%
%-read and prepare mri
%-----------------%
%-read
mri = ft_read_mri(mrifile);
%-----------------%
 
%-----------------%
%-segmenting the volume, Tissue Probability Maps
cfg1 = [];
cfg1.threshold  = [];
cfg1.output = 'tpm';
cfg1.coordsys = 'spm';
tpm = ft_volumesegment(cfg1, mri);
tpm.anatomy = mri.anatomy;
%-----------------%

%-----------------%
%-segmenting the volume
cfg1 = [];
cfg1.threshold  = cfg.mri2vol.tpmthreshold;
cfg1.output = 'scalp';
cfg1.coordsys = 'spm';
segscalp = ft_volumesegment(cfg1, tpm);

cfg1 = [];
cfg1.threshold  = [];
cfg1.output = {'skull' 'brain'};
cfg1.coordsys = 'spm';
segment = ft_volumesegment(cfg1, tpm);
segment.scalp = segscalp.scalp;

clear segscalp
%-----------------%
%-------------------------------------%

%-------------------------------------%
%-mesh and headmodel
M = segment.transform;

%-----------------%
%-prepare mesh for skull and brain (easy)
cfg2 = [];
cfg2.tissue = {'skull', 'brain'};
cfg2.numvertices = cfg.mri2vol.numvertices(2:3);
cfg2.transform = M;
bnd = ft_prepare_mesh_new(cfg2, segment);
%-----------------%

%-----------------%
%-prepare mesh for scalp
cfg2 = [];
cfg2.tissue = {'scalp'};
cfg2.numvertices = cfg.mri2vol.numvertices(1);
cfg2.thresholdseg = cfg.mri2vol.threshbnd;
cfg2.transform = M;
scalp = ft_prepare_mesh_new(cfg2, segment);
%-----------------%
  
%-----------------%
%-combine scalp and bnd
bnd = [scalp bnd];

save(bndfile, 'bnd')
%-----------------%

%-----------------%
%-headmodel
cfg3  = [];
cfg3.method = cfg.mri2vol.method;
cfg3.conductivity = cfg.mri2vol.conductivity;
vol = ft_prepare_headmodel(cfg3, bnd);
save(volfile, 'vol')
%-----------------%
%-------------------------------------%

%---------------------------%
%-end log
toc_t = toc(tic_t);
outtmp = sprintf('(p%02.f) %s (v%02.f) ended at %s on %s after %s\n\n', ...
  subj, mfilename, mversion, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([cfg.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%