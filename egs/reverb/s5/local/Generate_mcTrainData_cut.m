function Generate_mcTrainData_cut(WSJ_dir_name, RIR_dir, save_dir)
%
% Input variables:
%    WSJ_dir_name: string name of WAV file directory converted from original wsjcam0 SPHERE files
%                  (*Directory structure for wsjcam0 corpus to be kept as it is after obtaining it from LDC. 
%                    Otherwise this script does not work.)
%
% This function generates multi-condition training data
% based on the following items:
%  1. wsjcam0 corpus (WAV files)
%  2. room impulse responses (ones under ./RIR/)
%  3. noise (ones under ./NOISE/).
% Generated data has the same directory structure as original wsjcam0 corpus. 
%

if nargin<2
   error('Usage: Generate_mcTrainData(WSJCAM0_data_path, save_dir)  *Note that the input variable WSJCAM0_data_path should indicate the directory name of your clean WSJCAM0 corpus. '); 
end
if exist([WSJ_dir_name,'/data/'])==0
   error(['Could not find wsjcam0 corpus : Please confirm if ',WSJ_dir_name,' is a correct path to your clean WSJCAM0 corpus']); 
end

if ~exist('save_dir', 'var')
    error('You have to set the save_dir variable in the code before running this script!')
end

display(['Name of directory for original wsjcam0: ',WSJ_dir_name])
display(['Name of directory to save generated multi-condition training data: ',save_dir])

% Parameters related to acoustic conditions
SNRdB=20;

% List of WSJ speech data
flist1='etc/audio_si_tr.lst';

%
% List of RIRs
%
RIR_List = dir(strcat(RIR_dir, '/*.wav'));
num_RIRvar=length(RIR_List);

%
% List of noise
% 
num_NOISEvar=6;
noise_sim1='./NOISE/Noise_SmallRoom1';
noise_sim2='./NOISE/Noise_MediumRoom1';
noise_sim3='./NOISE/Noise_LargeRoom1';
noise_sim4='./NOISE/Noise_SmallRoom2';
noise_sim5='./NOISE/Noise_MediumRoom2';
noise_sim6='./NOISE/Noise_LargeRoom2';

%
% Start generating noisy reverberant data with creating new directories
%

fcount=1;
rcount=1;
ncount=1;

if save_dir(end)=='/';
    save_dir_tr=[save_dir,'data/mc_train/'];
else
    save_dir_tr=[save_dir,'/data/mc_train/'];
end
mkdir([save_dir_tr]);

mic_idx=['A';'B';'C';'D';'E';'F';'G';'H'];
prev_fname='dummy';

for nlist=1:1
    % Open file list
    eval(['fid=fopen(flist',num2str(nlist),',''r'');']);

    while 1
        
        % Set data file name
        fname=fgetl(fid);
        if ~ischar(fname);
            break;
        end
        
        idx1=find(fname=='/');  
        
        % Make directory if there isn't any
        if ~strcmp(prev_fname,fname(1:idx1(end)))
            mkdir([save_dir_tr fname(1:idx1(end))])
        end
        prev_fname=fname(1:idx1(end));
       
        % load speech signal
        x=audioread([WSJ_dir_name, '/data/', fname, '.wav'])';
        
        % load RIR and noise for "THIS" utterance
        RIR=audioread(strcat(RIR_List(rcount).folder,'/',RIR_List(rcount).name));
        eval(['NOISE=audioread([noise_sim',num2str(mod(floor(rcount/4), num_NOISEvar)+1),',''_',num2str(ncount),'.wav'']);']);

        % Generate 8ch noisy reverberant data        
        y=gen_obs(x,RIR,NOISE,SNRdB);

        % cut to length of original signal
        y = y(1:size(x,2),:);
        
        % rotine to cyclicly switch RIRs and noise, utterance by utterance 
        rcount=rcount+1;
        if rcount>num_RIRvar;rcount=1;ncount=ncount+1;end
        if ncount>10;ncount=1;end

        % save the data

        %y=y/4; % common normalization to all the data to prevent clipping
               % denominator was decided experimentally
	y=y/max(abs(y(:)));

        for ch=1:8
	    outfilename = [save_dir_tr, fname, '_ch', num2str(ch), '.wav'];
            eval(['audiowrite(outfilename, y(:,',num2str(ch),'), 16000);']);
        end
           
        display(['sentence ',num2str(fcount),' (out of 7861) finished! (Multi-condition training data)'])
        fcount=fcount+1;

    end
end


%%%%
function [y]=gen_obs(x,RIR,NOISE,SNRdB)
% function to generate noisy reverberant data

x=x';

% calculate direct+early reflection signal for calculating SNR
[val,delay]=max(RIR(:,1));
before_impulse=floor(16000*0.001);
after_impulse=floor(16000*0.05);
RIR_direct=RIR(max(delay-before_impulse,1):delay+after_impulse,1);
direct_signal=fconv(x,RIR_direct);

% obtain reverberant speech
for ch=1:8
    rev_y(:,ch)=fconv(x,RIR(:,ch));
end

% normalize noise data according to the prefixed SNR value
NOISE=NOISE(1:size(rev_y,1),:);
NOISE_ref=NOISE(:,1);

iPn = diag(1./mean(NOISE_ref.^2,1));
Px = diag(mean(direct_signal.^2,1));
Msnr = sqrt(10^(-SNRdB/10)*iPn*Px);
scaled_NOISE = NOISE*Msnr;
y = rev_y + scaled_NOISE;
y = y(delay:end,:);


%%%%
function [y]=fconv(x, h)
%FCONV Fast Convolution
%   [y] = FCONV(x, h) convolves x and h, and normalizes the output  
%         to +-1.
%
%      x = input vector
%      h = input vector
% 
%      See also CONV
%
%   NOTES:
%
%   1) I have a short article explaining what a convolution is.  It
%      is available at http://stevem.us/fconv.html.
%
%
%Version 1.0
%Coded by: Stephen G. McGovern, 2003-2004.
%
%Copyright (c) 2003, Stephen McGovern
%All rights reserved.
%
%THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
%AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
%IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
%ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
%LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
%CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
%SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
%CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
%ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%POSSIBILITY OF SUCH DAMAGE.

Ly=length(x)+length(h)-1;  % 
Ly2=pow2(nextpow2(Ly));    % Find smallest power of 2 that is > Ly
X=fft(x, Ly2);		   % Fast Fourier transform
H=fft(h, Ly2);	           % Fast Fourier transform
Y=X.*H;        	           % 
y=real(ifft(Y, Ly2));      % Inverse fast Fourier transform
y=y(1:1:Ly);               % Take just the first N elements
