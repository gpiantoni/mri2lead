function cpmri(cfg, subj)
%CPMRI copy MRI images into subject-folder and normalize them
%
% CFG
%  .rec: name of the recordings (part of the structrual filename)
%  .recs: name of recordings/RECNAME/subjects/
%  .data: name of projects/PROJNAME/subjects/
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%
%  .normalize: use '_spm' or '_flirt' for spatial normalization to MNI or
%  ''  for no normalization (note the underscore)
%  .smri: directory to copy all the structrual data to (can be empty)
%
% Part of MRI2LEAD
% see also CPMRI, MRI2VOL, VOL2LEAD, USETEMPLATE

%---------------------------%
%-start log
output = sprintf('(p%02.f) %s started at %s on %s\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
ft_hastoolbox('spm8', 2);

rdir = sprintf('%s%04.f/%s/%s/', cfg.recs, subj, cfg.vol.mod, 'raw'); % recording
mdir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.vol.mod, cfg.vol.cond); % mridata dir
if ~isdir(mdir); mkdir(mdir); end

rfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.vol.mod, cfg.vol.cond); % recording
mfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.vol.mod, cfg.vol.cond); % mridata

ext = '.nii.gz';
%---------------------------%

if exist([rdir rfile ext], 'file')
  
  %---------------------------%
  %-get data
  if ~exist([mdir mfile ext], 'file')
    system(['ln ' rdir rfile ext ' ' mdir mfile ext]);
  end
  %---------------------------%
  
  if strcmp(cfg.normalize, '_flirt')
    %-----------------------------------------------%
    %-USE FLIRT
    
    %---------------------------%
    %-realign
    %-------%
    %-bet
    bash(['bet ' mdir mfile ' ' mdir mfile '_brain -f 0.5 -g 0']);
    %-------%
    
    %-------%
    %-flirt
    bash(['flirt -in ' mdir mfile '_brain -ref /usr/share/data/fsl-mni152-templates/MNI152_T1_1mm_brain.nii.gz ' ...
      '-out ' mdir mfile '_brain_flirt -omat ' mdir mfile '_brain_flirt.mat ' ...
      '-bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12  -interp trilinear']);
    %-------%
    
    %-------%
    %-fnirt
    %-------%
    
    %-------%
    %-apply flirt
    bash(['flirt -in ' mdir mfile ' -ref /usr/share/data/fsl-mni152-templates/MNI152_T1_1mm_brain.nii.gz ' ...
      '-out ' mdir mfile cfg.normalize ' -applyxfm -init ' mdir mfile '_brain_flirt.mat']);
    %-------%
    
    %-------%
    %-feedback
    aff = dlmread([mdir mfile '_brain_flirt.mat']);
    
    outtmp = sprintf('flirt affine matrix:\n');
    for i = 1: (size(aff,1)-1)
      outtmp = sprintf('%s%s\n', outtmp, sprintf('% 9.3f', aff(i,:)));
    end
    output = [output outtmp];
    %-------%
    
    %-------%
    %-delete
    % delete([mdir '*_brain*'])
    %-------%
    %---------------------------%
    %-----------------------------------------------%
    
    
  elseif strcmp(cfg.normalize, '_spm')
    
    %-----------------------------------------------%
    %-spm
    %---------------------------%
    %-defaults for SPM
    refimg = [fullfile(fileparts(which('spm')), 'templates/T1.nii') ',1'];
    outsn = [mdir mfile '_sn.mat'];
    %-----------------%
    %-unzip
    gunzip([mdir mfile ext]);
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
    
    spm_normalise(refimg, [mdir mfile ext(1:4)], outsn, '', '', eflags);
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
    spm_write_sn([mdir mfile ext(1:4)], outsn, rflags);
    %---------------------------%
    
    %---------------------------%
    %-clean up
    uncomp = [mdir mfile cfg.normalize ext(1:4)];
    system(['mv ' mdir rflags.prefix mfile ext(1:4) ' ' uncomp]);
    gzip(uncomp);
    
    delete([mdir mfile ext(1:4)])
    delete(uncomp);
    %---------------------------%
    %-----------------------------------------------%
    
  end
  
  %---------------------------%
  %-copy data to main directory
  if ~isempty(cfg.smri)
    system(['ln ' mdir mfile cfg.normalize '.nii.gz ' cfg.smri mfile cfg.normalize ext]);
  end
  %---------------------------%
  
  
else
  
  outtmp = sprintf('%s for subject % 2.f does not exist\n', [rdir rfile ext], subj);
  output = [output outtmp];
  
end

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