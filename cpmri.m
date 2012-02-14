function cpmri(cfg, subj)
%CPMRI copy MRI images
% fslmaths gosd_svui_0001_smri_t1_brain.nii.gz -add gosd_svui_0002_smri_t1_brain.nii.gz -add gosd_svui_0003_smri_t1_brain.nii.gz -add gosd_svui_0004_smri_t1_brain.nii.gz -add gosd_svui_0006_smri_t1_brain.nii.gz -add gosd_svui_0006_smri_t1_brain.nii.gz -add gosd_svui_0007_smri_t1_brain.nii.gz -add gosd_svui_0008_smri_t1_brain.nii.gz -add gosd_svui_0009_smri_t1_brain.nii.gz -add gosd_svui_0010_smri_t1_brain.nii.gz -add gosd_svui_0011_smri_t1_brain.nii.gz -add gosd_svui_0012_smri_t1_brain.nii.gz -add gosd_svui_0013_smri_t1_brain.nii.gz -add gosd_svui_0015_smri_t1_brain.nii.gz -div 13 gosd_svui_avg_smri_t1_brain

mversion = 5;
%05 12/02/14 renamed to cpmri
%04 11/11/10 spm implemented as well, it works better (faster)
%03 11/11/10 use fsl
%02 11/11/10 away from swdti, into source
%01 11/10/11 created

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
addpath /usr/local/toolbox/fieldtrip/external/spm8/ % <- don't add normal spm8, but this simpler version

rdir = sprintf('%s%04.f/%s/%s/', cfg.recs, subj, cfg.mod, cfg.rawd); % recording
ddir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.mod, cfg.cond); % data
if ~isdir(ddir); mkdir(ddir); end

rfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.mod, cfg.cond); % recording
dfile = sprintf('%s_%s_%04.f_%s_%s', cfg.proj, cfg.rec, subj, cfg.mod, cfg.cond); % data

ext = '.nii.gz';
%---------------------------%


if exist([rdir rfile ext], 'file')
  
  %---------------------------%
  %-get data
  if ~exist([ddir dfile ext], 'file')
    system(['ln ' rdir rfile ext ' ' ddir dfile ext]);
  end
  %---------------------------%
  
  if strcmp(cfg.normalize, 'flirt')
    %-----------------------------------------------%
    %-USE FLIRT
    
    %---------------------------%
    %-realign
    %-------%
    %-bet
    system(['bet ' ddir dfile ' ' ddir dfile '_brain -f 0.5 -g 0']);
    %-------%
    
    %-------%
    %-flirt
    system(['flirt -in ' ddir dfile '_brain -ref /usr/share/data/fsl-mni152-templates/MNI152_T1_1mm_brain.nii.gz ' ...
      '-out ' ddir dfile '_brain_flirt -omat ' ddir dfile '_brain_flirt.mat ' ...
      '-bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12  -interp trilinear']);
    %-------%
    
    %-------%
    %-fnirt
    %-------%
    
    %-------%
    %-apply flirt
    system(['flirt -in ' ddir dfile ' -ref /usr/share/data/fsl-mni152-templates/MNI152_T1_1mm_brain.nii.gz ' ...
      '-out ' ddir dfile '_' cfg.normalize ' -applyxfm -init ' ddir dfile '_brain_flirt.mat']);
    %-------%
    
    %-------%
    %-feedback
    aff = dlmread([ddir dfile '_brain_flirt.mat']);
    
    outtmp = sprintf('flirt affine matrix:\n');
    for i = 1: (size(aff,1)-1)
      outtmp = sprintf('%s%s\n', outtmp, sprintf('% 9.3f', aff(i,:)));
    end
    output = [output outtmp];
    %-------%
    
    %-------%
    %-delete
    delete([ddir '*_brain*'])
    %-------%
    %---------------------------%
    %-----------------------------------------------%
    
    
  elseif strcmp(cfg.normalize, 'spm')
    
    %-----------------------------------------------%
    %-spm
    %---------------------------%
    %-defaults for SPM
    refimg = '/data/toolbox/spm8/templates/T1.nii,1';
    outsn = [ddir dfile '_sn.mat'];
    %-----------------%
    %-unzip
    gunzip([ddir dfile ext]);
    mfile = [dfile ext(1:4)];
    %-----------------%
    %---------------------------%
    
    %---------------------------%
    %-normalize
    eflags = [];
    eflags.smosrc = 8;
    eflags.smoref = 0;
    eflags.regtype = 'mni';
    eflags.cutoff = 25;
    eflags.nits = 16;
    eflags.reg = 1;
    
    spm_normalise(refimg, [ddir mfile], outsn, '', '', eflags);
    %---------------------------%
    
    %---------------------------%
    %-write
    rflags = [];
    rflags.preserve = 0;
    rflags.bb = [-100  -120 -100; 100 100 110];
    rflags.vox = [1 1 1];
    rflags.interp = 1;
    rflags.wrap = [0 0 0];
    rflags.prefix = 'w';
    spm_write_sn([ddir mfile], outsn, rflags);
    %---------------------------%
    
    %---------------------------%
    %-clean up
    uncomp = [ddir dfile '_' cfg.normalize ext(1:4)];
    system(['mv ' ddir rflags.prefix mfile ' ' uncomp]);
    gzip(uncomp);
    
    delete([ddir mfile])
    delete(uncomp);
    %---------------------------%
    %-----------------------------------------------%
    
  end
  
  %---------------------------%
  %-copy data to main directory
  if ~isempty(cfg.smri)
    system(['ln ' ddir dfile '_' cfg.normalize '.nii.gz ' cfg.smri dfile '_' cfg.normalize '.nii.gz']);
  end
  %---------------------------%
  
  
else
  
  outtmp = sprintf('%s for subject % 2.f does not exist\n', [rdir rfile ext], subj);
  output = [output outtmp];
  
end

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