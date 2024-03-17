function projectGUI

    % główny obraz
    mainFig = figure('Name', 'Project GUI', 'NumberTitle', 'off', 'Position', [100, 100, 800, 600]);
    
    % stwórz przycisk 'Load' 
    loadButton = uicontrol('Style', 'pushbutton', 'String', 'Load', 'Position', [20, 20, 100, 30], 'Callback', @loadImage);
    
    % stwórz przycisk 'Next' 
    nextButton = uicontrol('Style', 'pushbutton', 'String', 'Next', 'Position', [140, 20, 100, 30], 'Enable', 'off', 'Callback', @nextStep);
    
    % stwórz przycisk 'Reset' 
    resetButton = uicontrol('Style', 'pushbutton', 'String', 'Reset', 'Position', [260, 20, 100, 30], 'Callback', @resetGUI);

    % stwórz osie do wys. wykresow
    imgAxes = axes('Parent', mainFig, 'Position', [0.05, 0.2, 0.9, 0.7]);
   
    uicontrol('Style', 'text', 'String', 'Grid Rows:', 'Position', [360, 20, 80, 30], 'HorizontalAlignment', 'right');
    gridRowsEdit = uicontrol('Style', 'edit', 'Position', [445, 20, 40, 30], 'String', '4');

    uicontrol('Style', 'text', 'String', 'Grid Cols:', 'Position', [510, 20, 80, 30], 'HorizontalAlignment', 'right');
    gridColsEdit = uicontrol('Style', 'edit', 'Position', [595, 20, 40, 30], 'String', '4');

    % tabela do przechowywania obrazow
    setappdata(mainFig, 'originalImage', []);
    setappdata(mainFig, 'shuffledSubImages', []);
    setappdata(mainFig, 'reconstructedImage', []);
    setappdata(mainFig, 'currentStep', 0);

    function loadImage(~, ~)
        % wczytaj z pliku
        [filename, pathname] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp', 'Image Files (*.png, *.jpg, *.jpeg, *.bmp)'; '*.*', 'All Files (*.*)'}, 'Select Image');
        if filename
            imagePath = fullfile(pathname, filename);
            originalImage = imread(imagePath);
            setappdata(mainFig, 'originalImage', originalImage);

            % wyswietl obraz oryginalny
            axes('Parent', mainFig, 'Position', [0.05, 0.2, 0.9, 0.7]);
            imshow(originalImage);
            

            % wlaczy przycisk 'Next'
            set(nextButton, 'Enable', 'on');
        end
    end
    
    function nextStep(~, ~)
    currentStep = getappdata(mainFig, 'currentStep');
    gridRows = str2double(get(gridRowsEdit, 'String'));
    gridCols = str2double(get(gridColsEdit, 'String'));

    switch currentStep
        case 0
            % podziel na mniejsze obrazki
            subImages = extractSubImages(gridRows, gridCols);
            setappdata(mainFig, 'shuffledSubImages', subImages);

        case 1
            % rozlosuj obrazki
            shuffledSubImages = shuffleSubImages(gridRows, gridCols);
            setappdata(mainFig, 'shuffledSubImages', shuffledSubImages);
            displayshuffledSubImages(shuffledSubImages);

        case 2
            % uloz puzzle korzystajac z korelacji fazowej
            reconstructedImage = reconstructImage(gridRows, gridCols);
            setappdata(mainFig, 'reconstructedImage', reconstructedImage);
            displayReconstructedImage(reconstructedImage);

            % wylacz przycisk 'Next' 
            set(nextButton, 'Enable', 'off');
    end

    % zainkrementuj krok
    setappdata(mainFig, 'currentStep', currentStep + 1);
    end

    function resetGUI(~, ~)
    close(mainFig);
    projectGUI;
    end
    
    %funkcja do podzielenie obrazu na mniejsze
    function subImages = extractSubImages(gridRows, gridCols)
        originalImage = getappdata(mainFig, 'originalImage');

        [rows, cols, ~] = size(originalImage);
        subImageRows = floor(rows / gridRows);
        subImageCols = floor(cols / gridCols);

        subImages = cell(gridRows, gridCols);

        for i = 1:gridRows
            for j = 1:gridCols
                startRow = (i - 1) * subImageRows + 1;
                endRow = i * subImageRows;
                startCol = (j - 1) * subImageCols + 1;
                endCol = j * subImageCols;

                subImages{i, j} = originalImage(startRow:endRow, startCol:endCol, :);
            end
        end
    end

    %funkcja do losowego ulozenia obrazkow
    function shuffledSubImages = shuffleSubImages(gridRows, gridCols)
        subImages = getappdata(mainFig, 'shuffledSubImages');

        shuffledIndices = randperm(gridRows * gridCols);
        shuffCols = randperm(gridCols);
        shuffRows = randperm(gridRows);
        shuffledSubImages = subImages(shuffRows,:);
        shuffledSubImages = shuffledSubImages(:,shuffCols);

        combinedShuffledImage = cell2mat(reshape(shuffledSubImages, [1, numel(shuffledSubImages)]));
    end

    % funckja do ukladania z korelacja fazowa
    function reconstructedImage = reconstructImage(gridRows, gridCols)
        shuffledSubImages = getappdata(mainFig, 'shuffledSubImages');
        originalImage = getappdata(mainFig, 'originalImage');

        [rows, cols, ~] = size(originalImage);
        reconstructedImage = zeros(size(originalImage));

        fft2_original = fft2(rgb2gray(originalImage));

        for i = 1:gridRows
            for j = 1:gridCols
                subImage = shuffledSubImages{i, j};
                SubImSize = size(subImage);
                subImageGray = rgb2gray(subImage);
                subimfft2 = fft2(subImageGray, rows, cols);
                PhaseCorr = (fft2_original .* conj(subimfft2)) ./ abs(fft2_original .* conj(subimfft2));
                PhaseCorrAbs = abs(ifft2(PhaseCorr));
                [maxy, maxx] = find(PhaseCorrAbs == max(max(PhaseCorrAbs)));
                reconstructedImage(maxy:maxy + SubImSize(1) - 1, maxx:maxx + SubImSize(2) - 1, :) = shuffledSubImages{i, j};
            end
        end

        reconstructedImage = uint8(reconstructedImage);
    end
    
    function displayshuffledSubImages(combinedShuffledImage)
    combinedShuffledImage = cell2mat(combinedShuffledImage);


    axes(imgAxes);
    imshow(combinedShuffledImage);
    title('Shuffled images');
    end
    
    function displayReconstructedImage(reconstructedImage)
        axes(imgAxes);
        imshow(reconstructedImage);
        title('Image Reconstructed by Phase Correlation');
    end
end

