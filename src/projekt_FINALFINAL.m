clear all; close all;


originalImage = imread('Lenna.png');

originalImagenoise = originalImage;
reconstructedImage = zeros(size(originalImage));
figure(1)
image(originalImage)%wyswietla obraz oryginalny

[rows, cols, ~] = size(originalImage);

gridRows = 8;
gridCols = 8;
ValidMatrix=zeros(8,8);

subImageRows = floor(rows / gridRows);
subImageCols = floor(cols / gridCols);


subImages = cell(gridRows, gridCols);
subImagesSorted = cell(gridRows, gridCols);
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
         
%          subImages{i,j} = imrotate(subImages{i,j},rotationmatrix(randrot));
         subImages{i, j} = originalImage(startRow:endRow, startCol:endCol, :);
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
displayRow = 1;
displayCol = 1;
used=ones(8,8);

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
        ptsOriginal = detectSURFFeatures(edge(rgb2gray(originalImage),"canny",0.055),"MetricThreshold",750,"NumOctaves",1,"NumScaleLevels",6);
        ptsDistorted = detectSURFFeatures(edge(rgb2gray(shuffledSubImages{i,j}),"canny",0.09),"MetricThreshold",500,"NumOctaves",1,"NumScaleLevels",6);
        [featuresOriginal,validPtsOriginal] = extractFeatures(rgb2gray(originalImage),ptsOriginal);
        [featuresDistorted,validPtsDistorted] = extractFeatures(rgb2gray(shuffledSubImages{i,j}),ptsDistorted);
        indexPairs = matchFeatures(featuresOriginal,featuresDistorted);
        matchedOriginal = validPtsOriginal(indexPairs(:,1));
        matchedDistorted = validPtsDistorted(indexPairs(:,2));
        [tform, inlierIdx,status] = estgeotform2d(matchedDistorted,matchedOriginal,'similarity','Confidence',50,'MaxDistance',2 );
        inlierDistorted = matchedDistorted(inlierIdx,:);
        inlierOriginal = matchedOriginal(inlierIdx,:);
        invTform = invert(tform);
        Ainv = invTform.A;
        if status == 1
            ValidMatrix(i,j)=1;
            continue
        end
        ss = Ainv(1,2);
        sc = Ainv(1,1);
        scaleRecovered = hypot(ss,sc);

        thetaRecovered = atan2d(-ss,sc);
        d = 90;
        g = round(thetaRecovered./d).*d;
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

    if sum(reconstructedImage(maxy+round(0.2*SubImSize(1)):maxy+round(SubImSize(1)*0.8), maxx+round(0.2*SubImSize(2)):maxx+round(0.8*SubImSize(2)),1),"all")==0
        reconstructedImage(maxy:maxy+SubImSize(1)-1, maxx:maxx+SubImSize(2)-1,:)=subImageRotate;
        subImagesSorted{round(maxy/SubImSize(1))+1, round(maxy/SubImSize(2))+1}=subImageRotate;
        subImages{i,j}=0;
    else
        ValidMatrix(i,j)=1;
    end
       
       
    end
end


% Wyświetl najlepszą korelację i tłumaczenie
reconstructedImage=uint8(reconstructedImage);

% Zrekonstruuj oryginalny obraz, korzystając z najlepszego wyniku korelacji
wynik=sum(ValidMatrix,"all");



% Wyswietl zrekonstruowany obraz
figure(6);
imshow(reconstructedImage);
title('Obraz zrekonstruowany przez korelację fazową');
