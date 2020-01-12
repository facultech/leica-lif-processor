// Leica LIF Processor macro for z-projections by Tal Luigi and Daniel Waiger
// Based on the ZStacks Projector and Christophe Leterrier's Leica LIF Extractor macros
// Tested with ImageJ 1.52p and BioFormats 6.3.0
// Version 1.0.0 09/29/2019

macro "Leica LIF Processor" {
  // Get the folder name
  var directoryPath = getDirectory("Select a directory");

  print("\\Clear");
  print("directoryPath: " + directoryPath);

  // Get all file names
  var allNames = getFileList(directoryPath);
  var allExtensions = newArray(allNames.length);

  // Create extensions array
  for (var i = 0; i < allNames.length; i++) {
    var currentNameLength = lengthOf(allNames[i]);
    allExtensions[i] = substring(
      allNames[i],
      currentNameLength - 4,
      currentNameLength
    );
  }

  // Initialize choices variables
  var backgroundArray = newArray("None", "25", "50", "100", "200", "500");
  var filterArray = newArray("None", "Median", "Mean", "Gaussian", "Sigma");
  var projectionArray = newArray(
    "Average Intensity",
    "Max Intensity",
    "Min Intensity",
    "Sum Slices",
    "Standard Deviation",
    "Median"
  );
  var saveArray = newArray(
    "No, thanks",
    "In the source folder",
    "In a subfolder of the source folder",
    "In a folder next to the source folder",
    "In a custom folder"
  );

  // Create dialog box
  Dialog.create("Leica Projector");
  Dialog.addMessage("\n");
  Dialog.addChoice("Subtract background:", backgroundArray, "None");
  Dialog.addChoice("Filter:", filterArray, "None");
  Dialog.addChoice("Projection type:", projectionArray, "Sum Slices");
  Dialog.addChoice(
    "Save images?",
    saveArray,
    "In a subfolder of the source folder"
  );
  Dialog.addCheckbox("Reset spatial scales?", false);
  Dialog.addCheckbox("Close result images (if saved)?", true);
  Dialog.show();

  // Capture values from dialog box choices in variables
  var backgroundType = Dialog.getChoice();
  var filterType = Dialog.getChoice();
  var projectionType = Dialog.getChoice();
  var saveType = Dialog.getChoice();
  var resetScale = Dialog.getCheckbox();
  var closeChoice = Dialog.getCheckbox();

  setBatchMode(true);

  // Loop on all .lei and .lif extensions
  for (var n = 0; n < allExtensions.length; n++) {
    if (allExtensions[n] == ".lei" || allExtensions[n] == ".lif") {
      // Get the file path
      var filePath = directoryPath + allNames[n];

      // Store components of the file name
      var fileName = File.getName(filePath);
      var filePathLength = lengthOf(filePath);
      var fileNameLength = lengthOf(fileName);
      var fileDirectory = substring(filePath, 0, filePathLength - fileNameLength);
      var fileExtension = substring(fileName, fileNameLength - 4, fileNameLength);
      var fileShortname = substring(fileName, 0, fileNameLength - 4);

      print("");
      print("filePath: ", filePath);
      print("fileName: ", fileName);
      print("fileDirectory: ", fileDirectory);
      print("fileExtension: ", fileExtension);
      print("fileShortname: ", fileShortname);

      // Localize or create the output folder
      var outputDirectory = "Void";

      if (saveType == "In the source folder") {
        outputDirectory = fileDirectory;
      } else if (saveType == "In a subfolder of the source folder") {
        outputDirectory =
          fileDirectory + fileShortname + "_ZStacks" + File.separator;
        File.makeDirectory(outputDirectory);
      } else if (saveType == "In a folder next to the source folder") {
        outputDirectory = File.getParent(filePath);
        outputDirectory =
          outputDirectory + "_" + fileShortname + "_ZStacks" + File.separator;
        File.makeDirectory(outputDirectory);
      } else if (saveType == "In a custom folder") {
        outputDirectory = getDirectory("Choose the save folder");
      }

      print("outputDirectory: " + outputDirectory);
      print("");

      // Start BioFormats and get series number in file
      run("Bio-Formats Macro Extensions");

      var seriesCount;

      Ext.setId(filePath);
      Ext.getSeriesCount(seriesCount);
      var seriesNames = newArray(seriesCount);

      print("seriesCount: " + seriesCount);

      // Loop on all series in the file
      for (var i = 0; i < seriesCount; i++) {
        // Get series name and channels count
        var channelCount;

        Ext.setSeries(i);
        Ext.getEffectiveSizeC(channelCount);
        seriesNames[i] = "";
        Ext.getSeriesName(seriesNames[i]);
        var temporaryName = toLowerCase(seriesNames[i]);

        print(
          "seriesNames[" +
            i +
            "]: " +
            seriesNames[i] +
            " (temporaryName: " +
            temporaryName +
            ")"
        );

        // Import the series (split channels)
        run(
          "Bio-Formats Importer",
          "open=[" +
            filePath +
            "] " +
            "split_channels " +
            "view=[Standard ImageJ] " +
            "stack_order=Default " +
            "series_" +
            d2s(i + 1, 0)
        );

        // Loop on each channel (each opened window)
        for (var j = 0; j < channelCount; j++) {
          // Construct window name
          var temporaryChannel = d2s(j, 0);

          // Window has Series Name in title only if more than one Series exists
          var sourceWindowName;

          if (seriesCount == 1) {
            sourceWindowName = fileName + " - C=" + temporaryChannel;
          } else {
            sourceWindowName =
              fileName + " - " + seriesNames[i] + " - C=" + temporaryChannel;
          }

          var type = "";

          // Select source image and filter if asked
          selectWindow(sourceWindowName);

          if (backgroundType != "None") {
            run(
              "Subtract Background...",
              "rolling=" + backgroundType + " sliding disable stack"
            );

            type = type + " - BG";
          }

          if (filterType == "Median") {
            run("Median...", "radius=1 stack");
          } else if (filterType == "Mean") {
            run("Mean...", "radius=1 stack");
          } else if (filterType == "Gaussian") {
            run("Gaussian Blur...", "radius=1 stack");
          } else if (filterType == "Sigma") {
            run("Sigma Filter Plus", "radius=2 use=2 minimum=0.2 outlier stack");
          } else if (filterType != "None") {
            type = type + " - " + substring(filterType, 0, 3) + "Filt";
          }

          // Reset spatial scale of the projection if the option is chosen
          if (resetScale == true) {
            run("Set Scale...", "distance=0 known=1 pixel=1 unit=pixel");
          }

          // Project and save
          if (nSlices > 1) {
            run("Z Project...", "projection=[" + projectionType + "]");
          }

          // Rename image according to processing
          var newWindowName;

          if (seriesCount == 1) {
            newWindowName =
              "C=" +
              temporaryChannel +
              " - " +
              fileName +
              " - " +
              type +
              " - " +
              projectionType;
          } else {
            newWindowName =
              "C=" +
              temporaryChannel +
              " - " +
              fileName +
              " - " +
              type +
              " - " +
              projectionType +
              " - " +
              seriesNames[i];
          }

          rename(newWindowName);

          print("newWindowName: " + newWindowName);

          // Create output file path and save the output image
          var outputPath = "Void";

          if (saveType != "No, thanks") {
            outputPath = outputDirectory + newWindowName + ".tif";

            save(outputPath);

            // Close output image if asked
            if (closeChoice == true) {
              close();
            }
          }
        }
      }
    }
  }

  showMessage("Processing Completed");
  run("Close All");
  run("Collect Garbage");
  setBatchMode(false);
}
