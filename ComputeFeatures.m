%% ComputeFeatures.m
% Computes fundFreq, meanSpacing, numPeaks for each labeled base clip

clear; clc;

% --- 1. Folder and labeled base clips ---
Dir = 'C:\Users\ivand\MATLAB Drive\BME60B_PBL2_Shazam\Sound Clips\Chosen Clips';

baseLabels = {'animals', 'classical', 'country', 'edm'};
baseFiles  = {
    fullfile(Dir, 'animals.aifc')
    fullfile(Dir, 'classical.aifc')
    fullfile(Dir, 'country.aifc')
    fullfile(Dir, 'edm.aifc')
};

n = numel(baseFiles);

fundFreqs    = zeros(n,1);
meanSpacings = zeros(n,1);
numPeaks     = zeros(n,1);

fprintf('=== Extracting features (fundFreq, meanSpacing, numPeaks) ===\n\n');

% --- 2. Loop over base clips and extract features ---
for i = 1:n
    filePath = baseFiles{i};
    [f0, mSpacing, nPeaks] = extractFeatures(filePath);  % helper below
    
    fundFreqs(i)    = f0;
    meanSpacings(i) = mSpacing;
    numPeaks(i)     = nPeaks;
    
    fprintf('File: %-10s\n', baseLabels{i});
    fprintf('   fundFreq    = %.2f Hz\n', f0);
    fprintf('   meanSpacing = %.2f Hz\n', mSpacing);
    fprintf('   numPeaks    = %d\n\n', nPeaks);
end

% --- 3. Summary table (nice for designing ranges) ---
T = table(baseLabels', fundFreqs, meanSpacings, numPeaks, ...
    'VariableNames', {'Type','FundFreq_Hz','MeanSpacing_Hz','NumPeaks'});
disp('--- Summary of base clip features ---');
disp(T);

%% OPTIONAL: simple auto-ranges from these 3 features (example)
% You can tweak or copy these into Shazam.m

% Fundamental frequency ranges (midpoint method)
[sortedFund, idxSort]   = sort(fundFreqs);
labelsSorted            = baseLabels(idxSort);

b1 = (sortedFund(1) + sortedFund(2))/2;
b2 = (sortedFund(2) + sortedFund(3))/2;
b3 = (sortedFund(3) + sortedFund(4))/2;

fundRanges = {
    [0,   b1];   % class 1
    [b1,  b2];   % class 2
    [b2,  b3];   % class 3
    [b3,  inf];  % class 4
};

fprintf('\nAuto fundamental ranges (by midpoints):\n');
for k = 1:4
    fprintf('%-10s : [%.1f, %.1f]\n', labelsSorted{k}, ...
        fundRanges{k}(1), fundRanges{k}(2));
end

% Mean spacing and numPeaks ranges (simple ± margin example)
spacingMargin = 0.5 * min(meanSpacings);  % you can adjust this
peakMargin    = 1;                        % ±1 peaks around each base

spacingRanges = cell(n,1);
peakRanges    = cell(n,1);

for i = 1:n
    spacingRanges{i} = [max(0, meanSpacings(i) - spacingMargin), ...
                             meanSpacings(i) + spacingMargin];
    peakRanges{i}    = [max(1, numPeaks(i) - peakMargin), ...
                             numPeaks(i) + peakMargin];
end

fprintf('\nAuto spacing and peak-count ranges:\n');
for i = 1:n
    fprintf('%-10s : spacing [%.1f, %.1f], numPeaks [%d, %d]\n', ...
        baseLabels{i}, ...
        spacingRanges{i}(1), spacingRanges{i}(2), ...
        peakRanges{i}(1), peakRanges{i}(2));
end

%% From here you can copy these ranges into Shazam.m, matching types
% e.g. animalFundRange = fundRanges{index_for_animals}, etc.


%% LOCAL FUNCTION: extractFeatures
% This matches the logic you already use in Shazam.m
function [fundFreq, meanSpacing, numPeaks] = extractFeatures(filePath)

    [sounds, fs] = audioread(filePath);
    left = sounds(:,1);               % left channel
    N    = length(left);

    % --- FFT & power spectrum (one-sided) ---
    Y  = fft(left);
    P2 = abs(Y/N).^2;                 % two-sided power
    P1 = P2(1:floor(N/2)+1);          % one-sided
    f  = fs*(0:floor(N/2))/N;

    % --- Find strong peaks (match your Shazam settings) ---
    if max(P1) == 0
        fundFreq    = NaN;
        meanSpacing = NaN;
        numPeaks    = 0;
        return;
    end

    [pk, locs] = findpeaks(P1, f, ...
        'MinPeakHeight', 0.2*max(P1), ...
        'MinPeakDistance', 20);       % same constraints as Shazam

    if isempty(pk)
        fundFreq    = NaN;
        meanSpacing = NaN;
        numPeaks    = 0;
        return;
    end

    % Sort peaks by height
    [~, idx]  = sort(pk, 'descend');
    freqSorted = locs(idx);

    % Use up to top 5 peaks
    Ntop     = min(5, numel(freqSorted));
    topFreqs = freqSorted(1:Ntop);

    % --- Feature 1: dominant (fundamental-ish) frequency ---
    fundFreq = topFreqs(1);

    % --- Feature 2 and 3: spacing & number of peaks ---
    if Ntop > 1
        spacing     = diff(topFreqs);
        meanSpacing = mean(spacing);
    else
        meanSpacing = NaN;
    end

    numPeaks = Ntop;
end
