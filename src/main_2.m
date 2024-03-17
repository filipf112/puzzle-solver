clear all; close all;

%wczytanie obraz
originalImage = imread('Lenna.png');
%ptsOriginal = detectSURFFeatures(rgb2gray(originalImage));

originalImagenoise=imnoise(originalImage,"gaussian",0.5);
 
 % Define the standard deviation for the Gaussian filter
filterStdDev = 1; % You can adjust this value based on your needs

% Create the Gaussian filter
gaussianFilter = fspecial('gaussian', [5 5], filterStdDev);

% Apply the filter to the noisy image
%  originalImagenoise = imfilter(originalImagenoise, gaussianFilter);
% originalImagenoise = 255 - originalImagenoise;
originalImagenoise = originalImage;
reconstructedImage = zeros(size(originalImage));
figure(1)
image(originalImage)%wyswietla obraz oryginalny

% Pobiera wielkość obrazu oryginalnego
[rows, cols, ~] = size(originalImage);

% Definiuje ilosc kolumn i wierszy
gridRows = 8;
gridCols = 8;

% liczy wielkość każdego obrazka
subImageRows = floor(rows / gridRows);
subImageCols = floor(cols / gridCols);

% Inicjalizuje tablice która będzie przechowywać obrazki
subImages = cell(gridRows, gridCols);
rotationmatrix= [0,90,180,270,360];
% Dzieli obraz oryginalny i zapisuje do tablicy
for i = 1:gridRows
    for j = 1:gridCols
        % Oblicz indeksy dla każdego podobrazu
        startRow = (i - 1) * subImageRows + 1;
        endRow = i * subImageRows;
        startCol = (j - 1) * subImageCols + 1;
        endCol = j * subImageCols;
        
        % Wyodrębnia podobraz
       randrot = randi(length(rotationmatrix));
         subImages{i, j} = originalImagenoise(startRow:endRow, startCol:endCol, :);
         subImages{i,j} = imrotate(subImages{i,j},rotationmatrix(randrot));
%          subImages{i, j} = originalImage(startRow:endRow, startCol:endCol, :);
    end
end

% Wyświetla podobrazy 
figure(2);

for i = 1:gridRows
    for j = 1:gridCols
        % tworzy subplot
        subplot(gridRows, gridCols, (i-1)*gridCols + j);
        
        % wyświetla podobraz
        imshow(subImages{i, j});
        
    end
end


shuffledIndices = randperm(gridRows * gridCols); 
shuffCols = randperm(gridCols);
shuffRows = randperm(gridRows);
shuffledSubImages = subImages(shuffRows,:);
shuffledSubImages = shuffledSubImages(:,shuffCols);
% wyswietla rozlosowane obrazy
figure(3);
for a=1:gridRows
    for b=1:gridCols
    subplot(gridRows, gridCols, (a-1)*gridCols + b);
        imshow(shuffledSubImages{a, b});
    end
end


% Wybieranie koordynatów podobrazu
displayRow = 6;
displayCol = 5;

% Wyswietla wybrany podobraz
figure(4);
imshow(subImages{displayRow, displayCol});
title(['Wybrany podobraz: (' num2str(displayRow) ', ' num2str(displayCol) ')']);

%Inicjalizacja zmiennych
fft2_original = fft2(rgb2gray(originalImage));
% fft2_original_noise = fft2(rgb2gray(originalImagenoise));


for i = 1:gridRows
    for j = 1:gridCols
        % Wyodrębnij bieżący obraz podrzędny
        while 1
        ptsOriginal = detectSURFFeatures(rgb2gray(originalImage));
        ptsDistorted = detectSURFFeatures(rgb2gray(shuffledSubImages{i,j}));
        [featuresOriginal,validPtsOriginal] = extractFeatures(rgb2gray(originalImage),ptsOriginal);
        [featuresDistorted,validPtsDistorted] = extractFeatures(rgb2gray(shuffledSubImages{i,j}),ptsDistorted);
        indexPairs = matchFeatures(featuresOriginal,featuresDistorted);
        matchedOriginal = validPtsOriginal(indexPairs(:,1));
        matchedDistorted = validPtsDistorted(indexPairs(:,2));
        [tform, inlierIdx,status] = estgeotform2d(matchedDistorted,matchedOriginal,'similarity');
        inlierDistorted = matchedDistorted(inlierIdx,:);
        inlierOriginal = matchedOriginal(inlierIdx,:);
        invTform = invert(tform);
        Ainv = invTform.A;

        ss = Ainv(1,2);
        sc = Ainv(1,1);
        scaleRecovered = hypot(ss,sc);

        thetaRecovered = atan2d(-ss,sc);
        d = 90;
        g = round(thetaRecovered./d).*d;
        if status==0
        break;
        elseif status == 1
            shuffledSubImages{i,j}=imrotate(shuffledSubImages{i,j},90);
            correlation_map = normxcorr2(rgb2gray(shuffledSubImages{i,j}), rgb2gray(originalImage));

    % Znajdź maksymalną wartość korelacji i jej położenie
    [max_correlation, max_index] = max(correlation_map(:));
    [ypeak, xpeak] = ind2sub(size(correlation_map), max_index(1));

    % Przesunięcie między obrazami
    offset_x = xpeak - size(rgb2gray(originalImage), 2);
    offset_y = ypeak - size(rgb2gray(originalImage), 1);

    % Kąt obrotu
    rotation_angle = atan2d(offset_y, offset_x);

    % Znormalizuj kąt do przedziału [0, 360)
    rotation_angle = mod(rotation_angle, 360);
    if rotation_angle==0
        break
    end
        end
        end
        subImage = shuffledSubImages{i, j};
        subImageRotate = imrotate(subImage,g);
        SubImSize=size(subImage);
        % Konwertuj obraz podrzędny na skalę szarości
        subImageGray = rgb2gray(subImageRotate);
        
        subimfft2=fft2(subImageGray,rows,cols);
        PhaseCorr=(fft2_original.*conj(subimfft2))./abs(fft2_original.*conj(subimfft2));
        PhaseCorrAbs=abs(ifft2(PhaseCorr));
        [maxy,maxx]=find(PhaseCorrAbs==max(max(PhaseCorrAbs)));
        
        maxy = round(maxy./SubImSize(1)).*SubImSize(1);
        maxx = round(maxx./SubImSize(2)).*SubImSize(2);
        if maxx == 0
            maxx=1;
        end
        if maxy == 0
            maxy=1;
        end
        reconstructedImage(maxy:maxy+SubImSize(1)-1, maxx:maxx+SubImSize(2)-1,:)=subImageRotate;
       disp(['Recovered theta: ', num2str(thetaRecovered)])
    end
end

% Wyświetl najlepszą korelację i tłumaczenie
reconstructedImage=uint8(reconstructedImage);

% Zrekonstruuj oryginalny obraz, korzystając z najlepszego wyniku korelacji




% Wyswietl zrekonstruowany obraz
figure(6);
imshow(reconstructedImage);
title('Obraz zrekonstruowany przez korelację fazową');
