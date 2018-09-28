//Plugin to detect wells in PDMS array images and extract intensity with time
//Arrays to store the results

var well_index = newArray();
var well_number = newArray();

var x_results = newArray();
var y_results = newArray();
var well_diameter = newArray();
var score = newArray();
var well_frame = newArray();

var red = newArray();
var green = newArray();
var brightfield = newArray();
var blue = newArray();

var	luts = newArray("Red", "Green", "Grays", "Blue");
var	names = newArray("Red", "Green", "Brightfield", "Blue");

Image = getTitle();

Stack.getDimensions(width, height, channels, slices, frames);
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

Dialog.create("Analysis Settings");
Dialog.addMessage("Please review the following");
Dialog.addCheckbox("Background Correction?", false);		//Subtract median autoflourescence
Dialog.addCheckbox("Dark Signal Correction?", true);		//Subtract mean of dark image or no-cell background
Dialog.addCheckbox("Normalise intensity Values?", true);
Dialog.addCheckbox("Use Max Intensity Projection?", true);
Dialog.show();
subt = Dialog.getCheckbox();
darkf = Dialog.getCheckbox();
norm_i = Dialog.getCheckbox();
max_ip = Dialog.getCheckbox();

split_and_focus(Image);

selectWindow("Brightfield");
type = bitDepth();
//needs to be in 8-bit here
run("8-bit");
detect_wells();
run(type+"-bit");

//link the wells
link_wells(x_results, y_results, well_frame, well_diameter);

//background subtract?
if (subt == 1) {
	waitForUser("Please select the control image of autoflourescence, set ROI (if required) and press OK");
}

back = getTitle;
getDimensions(width, height, channelCount, sliceCount, frameCount);
bchannels = channelCount;
s = selectionType();

if (s>-1) {
	Roi.getBounds(x, y, width, height);
	bx = x;
	by = y;
	bwidth = width;
	bheight = height;
} else {
		getDimensions(width, height, channelCount, sliceCount, frameCount);
		bx = 0;
		by = 0;
		bwidth = width;
		bheight = height;
}

//dark signal?
if (darkf == 1) {
	waitForUser("Please select the control image or ROI for dark image subtraction");
}

darkfield = getTitle;
getDimensions(width, height, channelCount, sliceCount, frameCount);
dchannels = channelCount;
s = selectionType();

if (s>-1) {
	Roi.getBounds(x, y, width, height);
	dx = x;
	dy = y;
	dwidth = width;
	dheight = height;
} else {
		getDimensions(width, height, channelCount, sliceCount, frameCount);
		dx = 0;
		dy = 0;
		dwidth = width;
		dheight = height;
}

if (subt == 1){
	get_median(back, bx, by, bwidth, bheight, bchannels);
	background(red, green);
}

if (darkf == 1){
	get_mean(darkfield, dx, dy, dwidth, dheight, dchannels);
	dark(red, green);
}

//measure intensities for each roi - loop through x-results and measure on x-y for each
run("Set Measurements...", "mean redirect=None decimal=5");
if (isOpen("Results")) {
	run("Close");	
	}

setBatchMode(true);

//measure channel1
for (i=0; i<x_results.length; i++) {
		selectWindow("Red");
		Stack.setSlice(well_frame[i]);
		makeOval(x_results[i]-(well_diameter[i]/2), y_results[i]-(well_diameter[i]/2), well_diameter[i], well_diameter[i]);
		run("Scale... ", "x=0.95 y=0.95 centered");
		run("Measure");
		mean = getResult("Mean", 0);
		red = Array.concat(red, mean);
		selectWindow("Results");
		run("Close");
}

//measure channel2
for (i=0; i<x_results.length; i++) {
		selectWindow("Green");
		Stack.setSlice(well_frame[i]);
		makeOval(x_results[i]-(well_diameter[i]/2), y_results[i]-(well_diameter[i]/2), well_diameter[i], well_diameter[i]);
		run("Scale... ", "x=0.95 y=0.95 centered");
		run("Measure");
		mean = getResult("Mean", 0);
		green = Array.concat(green, mean);
		selectWindow("Results");
		run("Close");
}

//measure channel3
for (i=0; i<x_results.length; i++) {
		selectWindow("Brightfield");
		Stack.setSlice(well_frame[i]);
		makeOval(x_results[i]-(well_diameter[i]/2), y_results[i]-(well_diameter[i]/2), well_diameter[i], well_diameter[i]);
		run("Scale... ", "x=0.95 y=0.95 centered");
		run("Measure");
		mean = getResult("Mean", 0);
		brightfield = Array.concat(brightfield, mean);
		selectWindow("Results");
		run("Close");
}

//measure channel4
if (channels>3){
for (i=0; i<x_results.length; i++) {
		selectWindow("Blue");
		Stack.setSlice(well_frame[i]);
		makeOval(x_results[i]-(well_diameter[i]/2), y_results[i]-(well_diameter[i]/2), well_diameter[i], well_diameter[i]);
		run("Scale... ", "x=0.95 y=0.95 centered");
		run("Measure");
		mean = getResult("Mean", 0);
		blue = Array.concat(blue, mean);
		selectWindow("Results");
		run("Close");
}
} else {
	for (i=0; i<x_results.length; i++) {
		blue = Array.concat(blue, "NA");
	}
}

setBatchMode(false);

//generate an roi set to use as a key from the data in the first frame

run("Colors...", "foreground=cyan background=cyan selection=cyan");

for (l=0; l<well_number.length; l++) {
	makeOval(x_results[l]-(well_diameter[l]/2), y_results[l]-(well_diameter[l]/2), well_diameter[l], well_diameter[l]);
	run("Scale... ", "x=0.95 y=0.95 centered");
	roiManager("Add");
	roiManager("Select", l);
	roiManager("Rename", "Well_"+well_number[l]);
}

//assemble the focused stack and add the roiset

if (channels>3){
	run("Merge Channels...", "c1=Red c2=Green c3=Blue c4=Brightfield create");
	} else {
		run("Merge Channels...", "c1=Red c2=Green c4=Brightfield create");
	}

roiManager("UseNames", "true");
roiManager("Show All with labels");

if (norm_i == 1) {

	//normalise the intnesity values red
	Array.getStatistics(red, min, max, mean, stdDev);
	for (i=0; i<red.length; i++) {
		red_v = red[i]-min;
		addToArray(red_v, red, i);
	}

	Array.getStatistics(red, min, max, mean, stdDev);
	for (i=0; i<red.length; i++) {
		red_v2 = red[i]/max;
		addToArray(red_v2, red, i);
	}

	//normalise the intnesity values green
	Array.getStatistics(green, min, max, mean, stdDev);
	for (i=0; i<green.length; i++) {
		green_v = green[i]-min;
		addToArray(green_v, green, i);
	}

	Array.getStatistics(green, min, max, mean, stdDev);
	for (i=0; i<green.length; i++) {
		green_v2 = green[i]/max;
		addToArray(green_v2, green, i);
	}

	//normalise the intnesity values blue
	Array.getStatistics(blue, min, max, mean, stdDev);
	for (i=0; i<blue.length; i++) {
		blue_v = blue[i]-min;
		addToArray(blue_v, blue, i);
	}


	Array.getStatistics(blue, min, max, mean, stdDev);
	for (i=0; i<blue.length; i++) {
		blue_v2 = blue[i]/max;
		addToArray(blue_v2, blue, i);
	}

	//normalise the intnesity values blue
	Array.getStatistics(brightfield, min, max, mean, stdDev);
	for (i=0; i<brightfield.length; i++) {
		brightfield_v = brightfield[i]-min;
		addToArray(brightfield_v, brightfield, i);
	}

	Array.getStatistics(brightfield, min, max, mean, stdDev);
	for (i=0; i<brightfield.length; i++) {	
		brightfield_v2 = brightfield[i]/max;
		addToArray(brightfield_v2, brightfield, i);
	}

}

//write the data to the results table
//draws the summary table
		requires("1.41g");
		title1 = "Summary Table";
		title2 = "["+title1+"]";
		ptab = title2;
		if (isOpen(title1)) {

			selectWindow(title1);
			run("Close");
			run("Table...", "name="+title2+" width=1000 height=300");
			print(ptab,"\\Headings:Index\tX\tY\tDiameter\tScore\tFrame\tRed\tGreen\tBrightfield\tBlue");
			
		}
			else {
				run("Table...", "name="+title2+" width=1000 height=300");
				print(ptab,"\\Headings:Index\tX\tY\tDiameter\tScore\tFrame\tRed\tGreen\tBrightfield\tBlue");
			}

//populate the table
for (k=0; k<x_results.length; k++) {
	print(ptab,well_index[k]+"\t"+x_results[k]+"\t"+y_results[k]+"\t"+well_diameter[k]+"\t"+score[k]+"\t"+well_frame[k]+"\t"+red[k]+"\t"+green[k]+"\t"+brightfield[k]+"\t"+blue[k]);
}

//setBatchMode("exit and display");

function detect_wells() {
	//Prompt for a single well
	run("Select None");
	setTool("oval");
	waitForUser("Select Well", "Please outline a single well and press OK");
	
	//Get diameter
	if (isOpen("Results")) {
		selectWindow("Results");
		run("Close");
	}
	
	run("Set Measurements...", "feret's redirect=None decimal=5");
	run("Measure");
	diameter = getResult("Feret", 0);
	
	if (isOpen("Results")) {
		selectWindow("Results");
		run("Close");
	}
	
	upper_d = ((round(diameter))/100)*110;
	lower_d = ((round(diameter))/100)*90;

	Stack.getDimensions(width, height, channels, slices, frames);

	for (i=1; i<=slices; i++) {
		Stack.setSlice(i);
		run("Detect Circles", "min_diameter=&lower_d max_diameter=&upper_d min_score=120");
		for  (j=0; j<nResults; j++) {
			x_results = Array.concat(x_results, getResult("x", j));
			y_results = Array.concat(y_results, getResult("y", j));
			well_diameter = Array.concat(well_diameter, getResult("Diameter", j));
			score = Array.concat(score, getResult("Score", j));
			well_frame = Array.concat(well_frame, i);
		}
	}

}

function normalised_variance(StackID) {

//Get image details
	type = bitDepth();
	if (type==8) {type="8-bit";} else {if(type==16) {type="16-bit";} else{if(type==32) {type="32-bit";} else {if(type==24) {type="RGB";}}}}
	//StackID=getTitle();
	Stack.getDimensions(width, height, channels, slices, frames);

//Check its in the correct format
	if (channels>1) {exit("The hyperstack has 2-channels please reduce dimensionality")} else{}
	if (channels==frames) {exit("The stack does not contain multiple z-positions")} else{}

//Subdivisions
	tiles = 4;

//Divide image into non-overlapping ROIs
	roiManager("reset");
	run("Select None");
	Stack.getDimensions(width, height, channels, slices, frames);

//note the divider must be a multiple of 4!!!!!!!!!

	x = 0;
	y = 0;
	width1 = width/tiles;
	height1 = height/tiles;
	spacing = 0;
	numRow = tiles;
	numCol = tiles;

	for(i = 0; i < numRow; i++)
	{
		for(j = 0; j < numCol; j++)
		{
			xOffset = j * (width1);
			yOffset = i * (height1);
			makeRectangle(x + xOffset, y + yOffset, width1, height1);
			roiManager("Add");
			
		}		
	}
	
	roiManager("Show All");
	number_ROI = roiManager("count");
	//setBatchMode(true);

//Work through the ROI set and pick the most infocus slice for each ROI
	for (k=1; k<=frames; k++) { Stack.setFrame(k);
	    for (z=0; z<number_ROI; z++){
	        normVar = 0;
	        normVar1 = 0;
	        m=0;
	        mean=0;
	        stdev=0;
		   for (l=1; l<=slices; l++){ 
	               selectWindow(StackID);
	               run("Select None");
	               roiManager("Select", z);
	               Stack.setFrame(k);
	               Stack.setSlice(l);
	               getStatistics(area, mean, min, max, std, histogram);
	               normVar = std*std/mean;
	                  if (normVar>normVar1) { 
		             m = l;
		             normVar1=normVar;}
		                else {normVar1 = normVar1;}
		}

//Build a new stack of the in-focus tiles at each timepoint
	selectWindow(StackID);
	run("Select None");
	roiManager("Select", z);
	Stack.setFrame(k);
	Stack.setSlice(m);
	run("Copy");
	if (isOpen(StackID+"_Focused")){
	                selectWindow(StackID+"_Focused");
	                if (z==0) {run("Add Slice");}
	            }
	            else{
	                newImage(StackID+"_Focused", type, height, width, 1);
	            }
	run("Restore Selection");
	run("Paste");
	selectWindow(StackID);
	Stack.setSlice(l);	
	      }
	}
	selectWindow("ROI Manager");
	run("Close");
	
	selectWindow(StackID);
	run("Close");
	selectWindow(StackID+"_Focused");
	rename(StackID);
	//setBatchMode("exit and display");	
}

function measure_stack(Image, ROI) {

	Stack.getDimensions(width, height, channels, slices, frames);

	for (i=1; i<=frames; i++){
		Stack.setFrame(i);
		for (j=1; j<=channels; j++) {
			Stack.setChannel(n);
			run("Clear Results");
			run("Measure");
			result = getResult("IntDen", 0);
			array = "c"+(j+1);
			array = Array.concat(result, array);
		}
	}
	
}

function link_wells(x_results, y_results, well_frame, well_diameter) {
//populates an array (well_number) that links the objects in the provided arrays by findng the closest object in each frame
//limit the search to within x,y +/- diameter

	Array.getStatistics(well_frame, min, max, mean, stdDev);
	frames_min = min;
	
//all the wells are in the first frame get them and number them
	for (i=0; i<x_results.length; i++) {
		well=1;
		if (well_frame[i] == min) {
			well_number = Array.concat(well_number, well+i);
		}		
	}
	well_index = well_number;
	
//loop through each well and link to wells in the next frame
	xvals = newArray();
	yvals = newArray();
	
	for (i=0; i<well_number.length; i++) {
		xvals = Array.concat(xvals, x_results[i]);			//all the xvalues in the first frame
		yvals =	Array.concat(yvals, y_results[i]);			//all the yvalues in the first frame
	}

//fill well_index with values upto x_results.length
	
	//for (i=well_number.length+1; i<x_results.length; i++) {
	for (i=well_number.length; i<x_results.length; i++) {
		 well_index = Array.concat(well_index, "NA");
	}
	
//loop through everythng outside frame 1 and ask if its within diameter of a pair of points in xvals, yvals if so assign a well nuber form well_number

	for (i=0; i<x_results.length; i++) {
		if (well_frame[i]==1) {} else {
		x = x_results[i]; 
		y = y_results[i];
		dia = well_diameter[i];
		nwell = nearest_object(x, y, xvals, yvals, dia, well_number);
		addToArray(nwell, well_index, i);
		}	
	}
}

function nearest_object(x, y, xvalues, yvalues, dia, well_number) {
//finds the nearest pair of cell to a parent by looking at the x positons of the cells in the next row/level names accordingly by adding the left or righ delimeter
	distances = newArray();

//get all the distances from the object to the objects in the array
	for (i=0; i<xvalues.length; i++) {
			xdist = x - xvalues[i];
			ydist = y - yvalues[i];
			dist1 = sqrt((xdist*xdist)+(ydist*ydist));
			distances = Array.concat(distances, dist1);		
		}
	
//find the shortest distance in the array of distances

	Array.getStatistics(distances, min, max, mean, stdDev);
	min_dist = min;
	min_dist1 = index(distances, min_dist);
	
	if (min_dist < dia) {
		nwell = well_number[min_dist1];
		
	} else {nwell = 666;}//no correspondning well in frame 1
	//print(nwell);
	return(nwell);
	
}

function index(a, value) { 
//retreive the index of an object in an array
      for (i=0; i<a.length; i++) 
          if (a[i]==value) return i; 
      return -1; 
  } 

function addToArray(value, array, position) {
//allos one to update existing values in an array
//adds the value to the array at the specified position, expanding if necessary - returns the modified array
//From Richard Wheeler - http://www.richardwheeler.net/contentpages/text.php?gallery=ImageJ_Macros&file=Array_Tools&type=ijm
    
    if (position < lengthOf(array)) {
        array[position]=value;
    } else {
        temparray = newArray(position+1);
        for (i=0; i<lengthOf(array); i++) {
            temparray[i]=array[i];
        }
        temparray[position]=value;
        array=temparray;
    }
    return array;
}

function split_and_focus(image) {
//Splits the image into chanels and individually focuses each chanel

	//work out how many channels
	Stack.getDimensions(width, height, channels, slices, frames);

	//setBatchMode(true);
	//split the channels
	selectWindow(image);
	run("Select None");
	run("Duplicate...", "title=Duplicate duplicate");
	run("Split Channels");

	if (max_ip == 1) {
	//name the channels and apply luts
	for (i=0; i<channels; i++) {
		selectWindow("C"+i+1+"-"+"Duplicate");
		run("Z Project...", "projection=[Max Intensity] all");
		run(luts[i]);
		rename(names[i]);
		resetMinAndMax;
		}
	//setBatchMode("exit and display");
	} else {
	//name the channels and apply luts
	for (i=0; i<channels; i++) {
		selectWindow("C"+i+1+"-"+"Duplicate");
		normalised_variance("C"+i+1+"-"+"Duplicate");
		run(luts[i]);
		rename(names[i]);
		resetMinAndMax;
		}
	//setBatchMode("exit and display");
	}
}

function get_mean(image, x, y, width, height, channelCount) {

	run("Measure");
	run("Clear Results");
	
	setBatchMode(true);
	run("Set Measurements...", "mean redirect=None decimal=3");
	
	if (channelCount < 2) {
		exit("Error: Only one channel! Is this a multidimensional image?");
		} else {//if (channels <= 2) {
	
	selectWindow(image);
	run("Select None");
	run("Duplicate...", "title=Background duplicate");
	run("Split Channels");
	selectWindow("C1-"+"Background");
	rename("Background_Red");
	makeRectangle(x, y, width, height);
	run("Crop");
	run("Measure");
	run("Close");
	mean_red = getResult("Mean", 0);
	
	selectWindow("C3-"+"Background");
	rename("Background_Green");
	makeRectangle(x, y, width, height);
	run("Crop");
	run("Measure");
	run("Close");
	mean_green = getResult("Mean", 1);
	
	if (isOpen("C2-"+"Background")) {
		selectWindow("C2-"+"Background");
		run("Close");
		}
	if (isOpen("Results")) {
		selectWindow("Results");
		//run("Close");
		}
	}
	setBatchMode(false);
}

function get_median(image, x, y, width, height, channelCount) {

	run("Measure");
	run("Clear Results");
	
	setBatchMode(true);
	run("Set Measurements...", "median redirect=None decimal=3");
	
	if (channelCount < 2) {
		exit("Error: Only one channel! Is this a multidimensional image?");
		} else {//if (channels <= 2) {
	
	selectWindow(image);
	run("Select None");
	run("Duplicate...", "title=Background duplicate");
	run("Split Channels");
	selectWindow("C1-"+"Background");
	rename("Background_Red");
	makeRectangle(x, y, width, height);
	run("Crop");
	run("Measure");
	run("Close");
	median_red = getResult("Median", 0);
	
	selectWindow("C3-"+"Background");
	rename("Background_Green");
	makeRectangle(x, y, width, height);
	run("Crop");
	run("Measure");
	run("Close");
	median_green = getResult("Median", 1);
	
	if (isOpen("C2-"+"Background")) {
		selectWindow("C2-"+"Background");
		run("Close");
		}
	if (isOpen("Results")) {
		selectWindow("Results");
		//run("Close");
		}
	}
	setBatchMode(false);
}

function background(red, green) {
//subtract median autoflourescence signal from cells
//the function get_median gets these values
	selectWindow(red);
	run("Subtract...", "value=&median_red");
	run("Enhance Contrast...", "saturated=0 normalize");
	selectWindow(green);
	run("Subtract...", "value=&median_green");
	run("Enhance Contrast...", "saturated=0 normalize");
}

function dark(red, green) {
//subtract the mean dark value from a reference image or no cell background
//the function get_mean getsthese values
	selectWindow(red);
	run("Subtract...", "value=&mean_red");
	run("Enhance Contrast...", "saturated=0 normalize");
	selectWindow(green);
	run("Subtract...", "value=&mean_green");
	run("Enhance Contrast...", "saturated=0 normalize");
}

//Adds the value to the array at the specified position, expanding if necessary
//Returns the modified array
function addToArray(value, array, position) {
    if (position<lengthOf(array)) {
        array[position]=value;
    } else {
        temparray=newArray(position+1);
        for (i=0; i<lengthOf(array); i++) {
            temparray[i]=array[i];
        }
        temparray[position]=value;
        array=temparray;
    }
    return array;
}
