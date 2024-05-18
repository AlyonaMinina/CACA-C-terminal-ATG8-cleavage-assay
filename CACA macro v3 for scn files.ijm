            // Clear the log window if it was open
if (isOpen("Log")){
    selectWindow("Log");
    run("Close");
}

// Print the greeting
print(" ");
print("Warm welcome to the CACA macro (C-terminal ATG8 Cleavage Assay) v1!");
print(" ");
print("This assay version is designed for analyzing Western Blots that detect ATG8 with N-terminal and C-terminal tags (Ntag and Ctag, respectively).");
print("The WB images are expected to contain three bands for each sample:");
print("1. Top  band = Ntag–ATG8–Ctag");
print("2. Middle  band = Ntag–ATG8 or ATG8–Ctag");
print("3. Bottom  band = Free Ntag or Ctag");
print("The macro will calculate the intensity of each band, expressed as percent of total tag signal detected in the sample ");
print(" ");
print("Please select the folder with images for analysis");
print(" ");

// Find the original directory and create a new one for quantification results
original_dir = getDirectory("Select a directory");
original_folder_name = File.getName(original_dir);
output_dir = original_dir + "Results" + File.separator;
File.makeDirectory(output_dir);

// Create the table for all assays results
Table.create("Assay Results");

// Get a list of all the files in the directory
file_list = getFileList(original_dir);

// Create a shorter list containing .scn files only
scn_list = newArray(0);
for(s = 0; s < file_list.length; s++) {
    if(endsWith(file_list[s], ".scn")) {
        scn_list = Array.concat(scn_list, file_list[s]);
    }
}

// Inform the user about how many images will be analyzed from the selected folder
print(scn_list.length + " images were detected for analysis");
print("");

// Loop analysis through the list of .scn files
for (i = 0; i < scn_list.length; i++){
    path = original_dir + scn_list[i];
    run("Bio-Formats Windowless Importer", "open=path");    

    // Get the image file title and remove the extension from it    
    title = getTitle();
    a = lengthOf(title);
    b = a-4;
    short_name = substring(title, 0, b);
    selectWindow(title);

    // Print for the user what image is being processed
    print ("Processing image " + (i+1) + " out of " + scn_list.length + ":");
    print(title);
    print("");

    // Ask the user how to call this quantification
    Assay_title = "AZD";
    Dialog.create("Information about your quantification");
    Dialog.addString("Assay title", Assay_title);
    Dialog.addChoice("Detection of the tag:", newArray("N-tag", "C-tag"));
    Dialog.show();
    Assay_title = Dialog.getString();
    Assay_title = Assay_title + " " + short_name;
    Tag_detected = Dialog.getChoice();

    // Place the ROIs for each band
    run("ROI Manager...");
    run("Invert"); // use this for .scn files, comment out for tif files
    
    // Wait for the user to crop/rotate the image and save the result
    waitForUser("Please crop and rotate the image if needed. Hit ok to proceed to the rotation tool"); 
    run("Rotate... ");
    saveAs("Tiff", output_dir + Assay_title + ".tif");

    // Make sure ROI Manager is clean of any additional ROIs
    roiManager("reset");
    setTool("rectangle");
    roiManager("Show All");
    roiManager("Show All with labels");
    
    // Wait for the user to adjust the ROIs size and position
    waitForUser("Add all ROIs to ROI manager, then hit OK.\n\n1. For each lane select first the Ntag-ATG8-Ctag band, then the Ntag-ATG8 or ATG8-Ctag band and then free tag band.\n\n2. Add three ROIs selecting background for top, middle and bottom bands\n\n3. NB! Keep ROI size the same for all selections!\n\n3. Hit ok, when done! "); 
    
    // Rename the ROIs and save them
    sample_number = 1; // Initialize sample number
    n = roiManager("count"); // Fetch total number of ROIs
    // Loop through the ROIs
    for (r = 0; r < n; r++) {
        roiManager("Select", r);
        index_in_triplet = (r % 3) + 1; // Determine the index within the triplet. Adding 1 to start from 1 instead of 0
        // Determine the name based on the index within the triplet
       if (index_in_triplet == 1) {
	        roiManager("Rename", "Top band sample " + sample_number);
	    } else if (index_in_triplet == 2) {
	        roiManager("Rename", "Middle band sample " + sample_number);
	    } else if (index_in_triplet == 3) {
	        roiManager("Rename", "Bottom band sample " + sample_number);
	        sample_number = sample_number +1;
    	}    
	}
    // Rename the last three ROIs as background for the corresponding bands
    roiManager("Select", n-3);
    roiManager("Rename", "Top band background signal");
    roiManager("Select", n-2);
    roiManager("Rename", "Middle band background signal");
    roiManager("Select", n-1);
    roiManager("Rename", "Bottom band background signal");
    roiManager("Show All with labels");
    roiManager("Save", output_dir + Assay_title +"_ROIs.zip");

    // Measure and save Integrated Density within each ROI
    run("Invert");
    for ( r=0; r<n; r++ ) {
        run("Clear Results");
        roiManager("Select", r);
        ROI_Name = Roi.getName();
        run("Set Measurements...", "area integrated redirect=None decimal=3");
        roiManager("Measure");
        area = getResult("Area", 0);
        IntDen = getResult("IntDen", 0);
        RawIntDen = getResult("RawIntDen", 0);
        current_last_row = Table.size("Assay Results");
        Table.set("Assay name", current_last_row, Assay_title, "Assay Results");
        Table.set("Band name", current_last_row, ROI_Name, "Assay Results");
        Table.set("Band area", current_last_row, area, "Assay Results");
        Table.set("IntDen", current_last_row, IntDen, "Assay Results");
        Table.set("RawIntDen", current_last_row, RawIntDen, "Assay Results");
    }

    // Create a column for Integrated density without background specific for each analyzed image
    current_last_row = Table.size("Assay Results"); // Get the number of rows in the table
    current_assay_rows = newArray(current_last_row); // Create an array to store rows belonging to the currently processed image    
    // Iterate through the table to find rows belonging to the currently processed image
    current_row_count = 0; // Initialize a counter for the current assay rows
    for (row = 0; row < current_last_row; row++) {
        Assay_subset = Table.getString("Assay name", row, "Assay Results"); 
        if (Assay_subset == Assay_title) {
            current_assay_rows[current_row_count] = row; // Assign the current row index to the current assay rows array
            current_row_count++; // Increment the counter for the next row index
        }
    }
    
    // Trim the array to remove any unused elements
    Array.trim(current_assay_rows, current_row_count);

    // Fetch background values for the currently processed images
    Background_for_Top = Table.get("RawIntDen", current_last_row-3, "Assay Results");
    Background_for_Middle = Table.get("RawIntDen", current_last_row-2, "Assay Results");
    Background_for_Bottom = Table.get("RawIntDen", current_last_row-1, "Assay Results");    
    
    // Process each row belonging to the currently processed image
    for (r = 0; r < current_row_count; r++) {
        row = current_assay_rows[r];
        Band_name = Table.getString("Band name", row, "Assay Results"); 
        if(indexOf(Band_name, "Top")==0) {
            Current_RawIntDen = Table.get("RawIntDen", row, "Assay Results");
            IntDen_without_background = Current_RawIntDen - Background_for_Top;
        } 
        if(indexOf(Band_name, "Middle")==0) {    
            Current_RawIntDen = Table.get("RawIntDen", row, "Assay Results");
            IntDen_without_background = Current_RawIntDen - Background_for_Middle;
        }
        if(indexOf(Band_name, "Bottom")==0) {   
            Current_RawIntDen = Table.get("RawIntDen", row, "Assay Results");
            IntDen_without_background = Current_RawIntDen - Background_for_Bottom;
        } 
        Table.set("RawIntDen_without_background", row, IntDen_without_background, "Assay Results");
    }

    // Create a column with sample numbers
    current_last_row = Table.size("Assay Results");
    for (row = 0; row < current_last_row; row++) {
        Band_name = Table.getString("Band name", row, "Assay Results"); 
        Sn_extraction = lastIndexOf(Band_name, "sample");
        if (Sn_extraction >= 0) {                   
            Sample_number = substring(Band_name, Sn_extraction);
            Table.set("Sample number", row, Sample_number, "Assay Results");
        }
    }
    Table.set("Sample number", current_last_row-3, "","Assay Results"); // Clean up the values for the two background rows
    Table.set("Sample number", current_last_row-2, "","Assay Results");
    Table.set("Sample number", current_last_row-1, "","Assay Results");
    
    // Create a column with new band names    
    current_last_row = Table.size("Assay Results"); // Get the number of rows in the table
    current_assay_rows = newArray(current_last_row); // Create an array to store rows belonging to the currently processed image
    current_row_count = 0; // Initialize a counter for the current assay rows
    // Iterate through the table to find rows belonging to the currently processed image
    for (row = 0; row < current_last_row; row++) {
        Assay_subset = Table.getString("Assay name", row, "Assay Results"); 
        if (Assay_subset == Assay_title) {
            current_assay_rows[current_row_count] = row; // Assign the current row index to the current assay rows array
            current_row_count++; // Increment the counter for the next row index
        }
    }
    
    // Trim the array to remove any unused elements
    Array.trim(current_assay_rows, current_row_count);

    // Process each row belonging to the currently processed image
    for (r = 0; r < current_row_count; r++) {
        assay_row = current_assay_rows[r];
        Band_name = Table.getString("Band name", assay_row, "Assay Results"); 
        if (Tag_detected == "N-tag") {
            if (indexOf(Band_name, "Top") == 0) {
                Table.set("New band name", assay_row, "Ntag-ATG8-Ctag complete fusion protein", "Assay Results");
            } 
            if (indexOf(Band_name, "Middle") == 0) {    
                Table.set("New band name", assay_row, "Ntag-ATG8 partial fusion protein", "Assay Results");
            } 
            if (indexOf(Band_name, "Bottom") == 0) {   
                Table.set("New band name", assay_row, "Free Ntag", "Assay Results");
            } 
        } else {
            if (indexOf(Band_name, "Top") == 0) {
                Table.set("New band name", assay_row, "Ntag-ATG8-Ctag complete fusion protein", "Assay Results");
            } 
            if (indexOf(Band_name, "Middle") == 0) {    
                Table.set("New band name", assay_row, "ATG8-Ctag partial fusion protein", "Assay Results");
            } 
            if (indexOf(Band_name, "Bottom") == 0) {   
                Table.set("New band name", assay_row, "Free Ctag", "Assay Results");
            } 
        }
    }

    // Clean up the values for the two background rows
    current_last_row = Table.size("Assay Results");
    Table.set("New band name", current_last_row - 3, "", "Assay Results");
    Table.set("New band name", current_last_row - 2, "", "Assay Results");
    Table.set("New band name", current_last_row - 1, "", "Assay Results");

    // Create a column with calculation for the top band, expressed as % of all tagged protein detected in the sample
    current_last_row = Table.size("Assay Results");
    for (row = 0; row < current_last_row; row++) {
        Total_Signal = (Table.get("RawIntDen_without_background", row, "Assay Results")) + 
                       (Table.get("RawIntDen_without_background", row+1, "Assay Results")) + 
                       (Table.get("RawIntDen_without_background", row+2, "Assay Results"));
        Top_band = Table.get("RawIntDen_without_background", row, "Assay Results");
        Top_band_percent = 100 * Top_band / Total_Signal;
        Table.set("Band intensity as % of cumulative tag signal detected in the sample", row, Top_band_percent, "Assay Results");
        row = row + 2;
    }

    // Add to the column calculations for the middle band, expressed as % of all tagged protein detected in the sample
    current_last_row = Table.size("Assay Results");
    for (row = 1; row < current_last_row; row++) {
        Total_Signal = (Table.get("RawIntDen_without_background", row-1, "Assay Results")) + 
                       (Table.get("RawIntDen_without_background", row, "Assay Results")) + 
                       (Table.get("RawIntDen_without_background", row+1, "Assay Results"));
        Middle_band = Table.get("RawIntDen_without_background", row, "Assay Results");
        Middle_band_percent = 100 * Middle_band / Total_Signal;
        Table.set("Band intensity as % of cumulative tag signal detected in the sample", row, Middle_band_percent, "Assay Results");
        row = row + 2;
    }

    // Add to the column calculations for the bottom band, expressed as % of all tagged protein detected in the sample
    current_last_row = Table.size("Assay Results");
    for (row = 2; row < current_last_row; row++) {
        Total_Signal = (Table.get("RawIntDen_without_background", row-2, "Assay Results")) + 
                       (Table.get("RawIntDen_without_background", row-1, "Assay Results")) + 
                       (Table.get("RawIntDen_without_background", row, "Assay Results"));
        Bottom_band = Table.get("RawIntDen_without_background", row, "Assay Results");
        Bottom_band_percent = 100 * Bottom_band / Total_Signal;
        Table.set("Band intensity as % of cumulative tag signal detected in the sample", row, Bottom_band_percent, "Assay Results");
        row = row + 2;
    }

    // Clean up the table from extra 0 and NaN values
    Table.set("Band intensity as % of cumulative tag signal detected in the sample", current_last_row-3, "", "Assay Results");    
    Table.set("Band intensity as % of cumulative tag signal detected in the sample", current_last_row-2, "", "Assay Results");    
    Table.set("Band intensity as % of cumulative tag signal detected in the sample", current_last_row-1, "", "Assay Results");    

    // Save the quantification results into a .csv table file
    selectWindow("Results");
    run("Close");
    Table.save(output_dir + "ImageJ macro results" + ".csv");
    run("Close All");
}

// A feeble attempt to close those pesky ImageJ windows
run("Close All");

// Print the final message
print(" ");
print("All Done!");
print("Your quantification results are saved in the folder " + output_dir);
print(" "); 
print(" ");
print("Alyona Minina. 2024");

