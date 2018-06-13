// #ifdef documentation
// =========================================================================
// 
//      program: readEDF.c
//           by: Roy Amit (based on Shlomit Yuval-Greenberg (based on justin gardner code))
//         date: 19/03/14
// 
// =========================================================================
// #endif
// Matlab command line syntax:: array=readEDF('filename.edf'); (dont try to call it with ans)
// NOTICE: Due to Matlab compiler Issues, the original code was simplified, making it more compatible with other subtypes of C)
// As part of these changes and due to ignorance in C language the messages output array needed to be in a constant size. 
//  >>>>>>>>THE NUMBER OF ELEMENTS IN THIS ARRAY IS SET IN LINE 75 AND CURRENTLY SUPPORTS 20000 MESSAGES!!!%@#$@$#%@$#%$#@
// YOU CAN EASILY CHANGE IT THERE IF YOU NEED MORE
/////////////////////////
//   include section   //
/////////////////////////
//#include "mgl_temp.h"
#include <mex.h>
#include "edf.h"


///////////////////////////////
//   function declarations   //
///////////////////////////////
void dispEventType(int eventType);
void dispEvent(int eventType, ALLF_DATA *event,int verbose);
int isEyeUsedMessage(int eventType, ALLF_DATA *event);



////////////////////////
//   define section   //
////////////////////////
#define STRLEN 2048
/* this is a hack, taken from opt.h in the EDF example code */
/* it is undocumented in the EyeLink code */
#define NaN 1e8  /* missing floating-point values*/

//////////////
//   main   //
//////////////
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  int err;
  char filename[STRLEN];
  int verbose = 1;
  int errval;
  EDFFILE *edf;
  int i,eventType,numSamples=0,numFix=0,numSac=0,numBlink=0;
  int numMessages = 0;
  int numInputs = 0;
//   int messagesCounter;
  int numElements;
  int numTrials;
  int setGazeCoords = 0;
  ALLF_DATA *data;
  // initialize the output structure
  const char *fieldNames[] =  {"filename","numElements","numTrials",
			       "EDFAPI","preamble","gazeLeft","gazeRight",
			       "fixations","saccades","blinks","messages",
			       "gazeCoords","frameRate","inputs"};
  int outDims[2] = {1,1};
  int preambleLength;
  char *cbuf;
  // mark beginning of file
  BOOKMARK startOfFile;
  // set an output fields for the gaze data
  const char *fieldNamesGaze[] =  {"time","x","y","pupil","pix2degX","pix2degY","velocityX","velocityY","whichEye"};
  int outDims2[2] = {1,1};
  const char *fieldNamesFix[] =  {"startTime","endTime","aveH","aveV"};
  int outDimsFix[2] = {1,1};
  const char *fieldNamesSac[] =  {"startTime","endTime","startH","startV","endH","endV","peakVel"};
  int outDimsSac[2] = {1,1};
  const char *fieldNamesBlinks[] =  {"startTime","endTime"};
  int outDimsBlinks[2] = {1,1};
  const char *fieldNamesMessages[] = {"message", "time"};
  int outDimsMessages[2] = {1,50000};// numMessages};
  const char *fieldNamesInputs[] = {"input", "time"};
  int outDimsInputs[2] = {1,50000};// numMessages};
  
  
  double *outptrTimeLeft;
  double *outptrXLeft;
  double *outptrYLeft;
  double *outptrPupilLeft;
  double *outptrPix2DegXLeft;
  double *outptrPix2DegYLeft;
  double *outptrVelXLeft;
  double *outptrVelYLeft;
  double *outptrWhichEyeLeft;
  double *outptrTimeRight;
  double *outptrXRight;
  double *outptrYRight;
  double *outptrPupilRight ;
  double *outptrPix2DegXRight;
  double *outptrPix2DegYRight ;       
  double *outptrVelXRight;
  double *outptrVelYRight;
  double *outptrWhichEyeRight;
  double *outptrFixStartTime;
  double *outptrFixEndTime;
  double *outptrFixAvgH;
  double *outptrFixAvgV; 
  double *outptrSacStartTime;
  double *outptrSacEndTime;
  double *outptrSacStartH;
  double *outptrSacStartV;
  double *outptrSacEndH;
  double *outptrSacEndV;
  double *outptrSacPeakVel;
  double *outptrBlinkStartTime;
  double *outptrBlinkEndTime;
  double *outptrCoords;
  double *outptrFrameRate;
  char snum[2048];
  int currentEye;
  size_t messagesCounter = 0;
  size_t inputsCounter = 0;
  mxArray *messagesStruct;
  mxArray *inputsStruct;
          
  // parse input arguments
//   if (nrhs<1) {
//     usageError("readEDF");
//     return;
//   }
 
  // get filename
  mxGetString(prhs[0], filename, STRLEN);

  // get verbose
  if (nrhs >= 2)
    verbose = (int) *mxGetPr(prhs[1]); 

  // open file
  if (verbose) mexPrintf("(readEDF) Opening EDF file %s\n",filename);

  edf = edf_open_file(filename,verbose,1,1,&errval);
  // and check that we opened correctly
  if (edf == NULL) {
    mexPrintf("(readEDF) Could not open file %s (error %i)\n",filename,errval);
    plhs[0] = mxCreateDoubleMatrix(0,0,mxREAL);
    return;
  }

  numElements = edf_get_element_count(edf);
  numTrials = edf_get_trial_count(edf);


  
  plhs[0] = mxCreateStructArray(1,outDims,14,fieldNames);
  
  // save some info about the EDF file in the output
  mxSetField(plhs[0],0,"filename",mxCreateString(filename));
  mxSetField(plhs[0],0,"numElements",mxCreateDoubleScalar(numElements));
  mxSetField(plhs[0],0,"numTrials",mxCreateDoubleScalar(numTrials));
  mxSetField(plhs[0],0,"EDFAPI",mxCreateString(edf_get_version()));


// save the preamble
  preambleLength = edf_get_preamble_text_length(edf);
  cbuf = (char *)malloc(preambleLength*sizeof(char));
  edf_get_preamble_text(edf,cbuf,preambleLength);
  mxSetField(plhs[0],0,"preamble",mxCreateString(cbuf));

  edf_set_bookmark(edf,&startOfFile);


  // count number of samples and events in file
  for (i=0;i<numElements;i++) {
    // get the event type and event pointer
    eventType = edf_get_next_data(edf);
    data = edf_get_float_data(edf);
    if (eventType == SAMPLE_TYPE) numSamples++;
    if (eventType == ENDSACC) numSac++;
    if (eventType == ENDFIX) numFix++;
    if (eventType == ENDBLINK) numBlink++;
    if (eventType == INPUTEVENT) numInputs++;
    if (eventType == MESSAGEEVENT){
      // We'll keep track of all messages //
      numMessages++;

      
    }
  }


        
  // set gaze left fields
  mxSetField(plhs[0],0,"gazeLeft",mxCreateStructArray(1,outDims2,9,fieldNamesGaze));
  mxSetField(mxGetField(plhs[0],0,"gazeLeft"),0,"time",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrTimeLeft = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeLeft"),0,"time"));
  mxSetField(mxGetField(plhs[0],0,"gazeLeft"),0,"x",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrXLeft = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeLeft"),0,"x"));
  mxSetField(mxGetField(plhs[0],0,"gazeLeft"),0,"y",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrYLeft = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeLeft"),0,"y"));
  mxSetField(mxGetField(plhs[0],0,"gazeLeft"),0,"pupil",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrPupilLeft = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeLeft"),0,"pupil"));
  mxSetField(mxGetField(plhs[0],0,"gazeLeft"),0,"pix2degX",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrPix2DegXLeft = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeLeft"),0,"pix2degX"));
  mxSetField(mxGetField(plhs[0],0,"gazeLeft"),0,"pix2degY",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrPix2DegYLeft = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeLeft"),0,"pix2degY"));
  mxSetField(mxGetField(plhs[0],0,"gazeLeft"),0,"velocityX",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrVelXLeft = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeLeft"),0,"velocityX"));
  mxSetField(mxGetField(plhs[0],0,"gazeLeft"),0,"velocityY",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrVelYLeft = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeLeft"),0,"velocityY"));
  mxSetField(mxGetField(plhs[0],0,"gazeLeft"),0,"whichEye",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrWhichEyeLeft = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeLeft"),0,"whichEye"));


  // set gaze right fields
  mxSetField(plhs[0],0,"gazeRight",mxCreateStructArray(1,outDims2,9,fieldNamesGaze));
  mxSetField(mxGetField(plhs[0],0,"gazeRight"),0,"time",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrTimeRight = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeRight"),0,"time"));
  mxSetField(mxGetField(plhs[0],0,"gazeRight"),0,"x",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrXRight = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeRight"),0,"x"));
  mxSetField(mxGetField(plhs[0],0,"gazeRight"),0,"y",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrYRight = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeRight"),0,"y"));
  mxSetField(mxGetField(plhs[0],0,"gazeRight"),0,"pupil",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrPupilRight = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeRight"),0,"pupil"));
  mxSetField(mxGetField(plhs[0],0,"gazeRight"),0,"pix2degX",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrPix2DegXRight = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeRight"),0,"pix2degX"));
  mxSetField(mxGetField(plhs[0],0,"gazeRight"),0,"pix2degY",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrPix2DegYRight = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeRight"),0,"pix2degY"));
  mxSetField(mxGetField(plhs[0],0,"gazeRight"),0,"velocityX",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrVelXRight = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeRight"),0,"velocityX"));
  mxSetField(mxGetField(plhs[0],0,"gazeRight"),0,"velocityY",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrVelYRight = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeRight"),0,"velocityY"));
  mxSetField(mxGetField(plhs[0],0,"gazeRight"),0,"whichEye",mxCreateDoubleMatrix(1,numSamples,mxREAL));
  outptrWhichEyeRight = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"gazeRight"),0,"whichEye"));

  // set output fields for fixations

          
  mxSetField(plhs[0],0,"fixations",mxCreateStructArray(1,outDimsFix,4,fieldNamesFix));
  mxSetField(mxGetField(plhs[0],0,"fixations"),0,"startTime",mxCreateDoubleMatrix(1,numFix,mxREAL));
  outptrFixStartTime = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"fixations"),0,"startTime"));
  mxSetField(mxGetField(plhs[0],0,"fixations"),0,"endTime",mxCreateDoubleMatrix(1,numFix,mxREAL));
  outptrFixEndTime = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"fixations"),0,"endTime"));
  mxSetField(mxGetField(plhs[0],0,"fixations"),0,"aveH",mxCreateDoubleMatrix(1,numFix,mxREAL));
  outptrFixAvgH = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"fixations"),0,"aveH"));
  mxSetField(mxGetField(plhs[0],0,"fixations"),0,"aveV",mxCreateDoubleMatrix(1,numFix,mxREAL));
  outptrFixAvgV = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"fixations"),0,"aveV"));

  // set output fields for saccades

  

          
  mxSetField(plhs[0],0,"saccades",mxCreateStructArray(1,outDimsFix,7,fieldNamesSac));
  mxSetField(mxGetField(plhs[0],0,"saccades"),0,"startTime",mxCreateDoubleMatrix(1,numSac,mxREAL));
  outptrSacStartTime = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"saccades"),0,"startTime"));
  mxSetField(mxGetField(plhs[0],0,"saccades"),0,"endTime",mxCreateDoubleMatrix(1,numSac,mxREAL));
  outptrSacEndTime = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"saccades"),0,"endTime"));
  mxSetField(mxGetField(plhs[0],0,"saccades"),0,"startH",mxCreateDoubleMatrix(1,numSac,mxREAL));
  outptrSacStartH = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"saccades"),0,"startH"));
  mxSetField(mxGetField(plhs[0],0,"saccades"),0,"startV",mxCreateDoubleMatrix(1,numSac,mxREAL));
  outptrSacStartV = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"saccades"),0,"startV"));
  mxSetField(mxGetField(plhs[0],0,"saccades"),0,"endH",mxCreateDoubleMatrix(1,numSac,mxREAL));
  outptrSacEndH = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"saccades"),0,"endH"));
  mxSetField(mxGetField(plhs[0],0,"saccades"),0,"endV",mxCreateDoubleMatrix(1,numSac,mxREAL));
  outptrSacEndV = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"saccades"),0,"endV"));
  mxSetField(mxGetField(plhs[0],0,"saccades"),0,"peakVel",mxCreateDoubleMatrix(1,numSac,mxREAL));
  outptrSacPeakVel = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"saccades"),0,"peakVel"));

  // set output fields for blinks

  mxSetField(plhs[0],0,"blinks",mxCreateStructArray(1,outDimsBlinks,2,fieldNamesBlinks));
  mxSetField(mxGetField(plhs[0],0,"blinks"),0,"startTime",mxCreateDoubleMatrix(1,numBlink,mxREAL));
  outptrBlinkStartTime = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"blinks"),0,"startTime"));
  mxSetField(mxGetField(plhs[0],0,"blinks"),0,"endTime",mxCreateDoubleMatrix(1,numBlink,mxREAL));
  outptrBlinkEndTime = (double *)mxGetPr(mxGetField(mxGetField(plhs[0],0,"blinks"),0,"endTime"));

  
  //inputs
  inputsStruct = mxCreateStructArray(2, outDimsInputs, 2, fieldNamesInputs);
  mxSetField(plhs[0], 0, "inputs", inputsStruct); 
        // Messages  
 // size_t messagesCounter = 0;
  messagesStruct = mxCreateStructArray(2, outDimsMessages, 2, fieldNamesMessages);
  mxSetField(plhs[0], 0, "messages", messagesStruct); 

  // gaze coordinates
  mxSetField(plhs[0],0,"gazeCoords",mxCreateDoubleMatrix(1,4,mxREAL));
  outptrCoords = (double *)mxGetPr(mxGetField(plhs[0],0,"gazeCoords"));

  // gaze coordinates
  mxSetField(plhs[0],0,"frameRate",mxCreateDoubleMatrix(1,1,mxREAL));
  outptrFrameRate = (double *)mxGetPr(mxGetField(plhs[0],0,"frameRate"));

  // go back go beginning of file
  edf_goto_bookmark(edf,&startOfFile);
  
  currentEye = -1;
  // go through all data in file
  if (verbose) mexPrintf("(readEDF) Looping over samples and events \n");

  for (i=0;i<numElements;i++) {
       //if (verbose) mexPrintf("(readEDF) 11111Opening EDF file %s\n",filename);
    // get the event type and event pointer
    eventType = edf_get_next_data(edf);
    data = edf_get_float_data(edf);
 //if (verbose) mexPrintf("(readEDF) 2222222222Opening EDF file %s\n",filename);
    // display event type and info
    if (verbose>3) dispEvent(eventType,data,1); 
    if (verbose>2) dispEventType(eventType);
    if (verbose>1) dispEvent(eventType,data,0); 
    //if (verbose) mexPrintf("(readEDF) 33333333333Opening EDF file %s\n",filename);
    // get samples
    switch(eventType) {
        case SAMPLE_TYPE:
      //if (verbose) mexPrintf("(readEDF) 444444444444Opening EDF file %s\n",filename);
      // copy out left eye
      currentEye = 0;
      *outptrTimeLeft++ = (double)data->fs.time;
      *outptrWhichEyeLeft++ = currentEye;
      if ((int)data->fs.gx[currentEye]==NaN) {
          *outptrXLeft++ = mxGetNaN();
          *outptrYLeft++ = mxGetNaN();
          *outptrPupilLeft++ = mxGetNaN();
          *outptrPix2DegXLeft++ = mxGetNaN();
          *outptrPix2DegYLeft++ = mxGetNaN();
          *outptrVelXLeft++ = mxGetNaN();
          *outptrVelYLeft++ = mxGetNaN();
        }
      else{
        *outptrXLeft++ = (double)data->fs.gx[currentEye];
        *outptrYLeft++ = (double)data->fs.gy[currentEye];
        *outptrPupilLeft++ = (double)data->fs.pa[currentEye];
        *outptrPix2DegXLeft++ = (double)data->fs.rx;
        *outptrPix2DegYLeft++ = (double)data->fs.ry;
        *outptrVelXLeft++ = (double)data->fs.gxvel[currentEye];
        *outptrVelYLeft++ = (double)data->fs.gyvel[currentEye];

      }
      // copy out right eye
      currentEye = 1;
      *outptrTimeRight++ = (double)data->fs.time;
      *outptrWhichEyeRight++ = currentEye;
      if ((int)data->fs.gx[currentEye]==NaN) {
          *outptrXRight++ = mxGetNaN();
          *outptrYRight++ = mxGetNaN();
          *outptrPupilRight++ = mxGetNaN();
          *outptrPix2DegXRight++ = mxGetNaN();
          *outptrPix2DegYRight++ = mxGetNaN();
          *outptrVelXRight++ = mxGetNaN();
          *outptrVelYRight++ = mxGetNaN();
        }
      else{
        *outptrXRight++ = (double)data->fs.gx[currentEye];
        *outptrYRight++ = (double)data->fs.gy[currentEye];
        *outptrPupilRight++ = (double)data->fs.pa[currentEye];
        *outptrPix2DegXRight++ = (double)data->fs.rx;
        *outptrPix2DegYRight++ = (double)data->fs.ry;
        *outptrVelXRight++ = (double)data->fs.gxvel[currentEye];
        *outptrVelYRight++ = (double)data->fs.gyvel[currentEye];
      }
      break;
    case ENDFIX:
      *outptrFixStartTime++ = (double)data->fe.sttime;
      *outptrFixEndTime++ = (double)data->fe.entime;
      *outptrFixAvgH++ = (double)data->fe.gavx;
      *outptrFixAvgV++ = (double)data->fe.gavy;
      break;
    case ENDSACC:
      *outptrSacStartTime++ = (double)data->fe.sttime;
      *outptrSacEndTime++ = (double)data->fe.entime;
      *outptrSacStartH++ = (double)data->fe.gstx;
      *outptrSacStartV++ = (double)data->fe.gsty;
      *outptrSacEndH++ = (double)data->fe.genx;
      *outptrSacEndV++ = (double)data->fe.geny;
      *outptrSacPeakVel++ = (double)data->fe.pvel;
      break;
    case ENDBLINK:
       // if (verbose) mexPrintf("(readEDF) 55555555555555Opening EDF file %s\n",filename);
      *outptrBlinkStartTime++ = (double)data->fe.sttime;
      *outptrBlinkEndTime++ = (double)data->fe.entime;
      break;
    case MESSAGEEVENT:
            //if (verbose) mexPrintf(&(data->fe.message->c));
            // Store all messages
            //if (verbose) mexPrintf("hihihi %s", mxCreateString("&(data->fe.message->c))");
            
      mxSetField(messagesStruct, messagesCounter, "message",mxCreateString(&(data->fe.message->c))); 
            
            //if (verbose) mexPrintf("(readEDF) 77777777777777777777Opening EDF file %s\n",filename);
      mxSetField(messagesStruct, messagesCounter, "time",mxCreateDoubleScalar((double)data->fe.sttime));
           
      messagesCounter++;
            //if (verbose) mexPrintf("(readEDF) 888888888888888888888888888Opening EDF file %s\n",filename);
            

      if ((strncmp(&(data->fe.message->c),"GAZE_COORDS",11) == 0) && (setGazeCoords == 0)) {
        char *gazeCoords = &(data->fe.message->c);
        char *tok;
        tok = strtok(gazeCoords," ");
        tok = strtok(NULL," ");
        *outptrCoords++ = (double)atoi(tok);
        tok = strtok(NULL," ");
        *outptrCoords++ = (double)atoi(tok);
        tok = strtok(NULL," ");
        *outptrCoords++ = (double)atoi(tok);
        tok = strtok(NULL," ");
        *outptrCoords++ = (double)atoi(tok);
        setGazeCoords = 1;
      }
      if (strncmp(&(data->fe.message->c),"FRAMERATE",9) == 0){
        char *msg = &(data->fe.message->c);
        char *tok;
        tok = strtok(msg, " ");
        tok = strtok(NULL," ");
        *outptrFrameRate++ = (double)atof(tok);
      }
      /* if (strncmp(&(data->fe.message->c),"!CAL",4) == 0){ */
      /*   char *calMessage = &(data->fe.message->c); */
      /*   char *tok; */
      /*   tok = strtok(calMessage, " "); */
      /*   tok = strtok(NULL," "); */
      /*   mexPrintf("%s\n", tok); */
      /* } */
      break;
    case INPUTEVENT:
            //if (verbose) mexPrintf(&(data->fe.message->c));
            // Store all messages
            //if (verbose) mexPrintf("hihihi %s", mxCreateString("&(data->fe.message->c))");
            
      mxSetField(inputsStruct, inputsCounter, "input",mxCreateDoubleScalar((double)data->fe.input));//String(&(data->fe.input->c))); 
            
            //if (verbose) mexPrintf("(readEDF) 77777777777777777777Opening EDF file %s\n",filename);
      mxSetField(inputsStruct, inputsCounter, "time",mxCreateDoubleScalar((double)data->fe.sttime));
           
      inputsCounter++;
            //if (verbose) mexPrintf("(readEDF) 888888888888888888888888888Opening EDF file %s\n",filename);
            


 
      /* if (strncmp(&(data->fe.message->c),"!CAL",4) == 0){ */
      /*   char *calMessage = &(data->fe.message->c); */
      /*   char *tok; */
      /*   tok = strtok(calMessage, " "); */
      /*   tok = strtok(NULL," "); */
      /*   mexPrintf("%s\n", tok); */
      /* } */
      break;      
    }
  }

  
  
  // free the bookmark
  edf_free_bookmark(edf,&startOfFile);

  // close file
  err = edf_close_file(edf);
  if (err) {
    mexPrintf("(readEDF) Error %i closing file %s\n",err,filename);
  }
}

   
///////////////////////
//   dispEventType   //
///////////////////////
void dispEventType(int dataType)
{
  mexPrintf("(readEDF) DataType is %i: ",dataType); 
  switch(dataType)  {
    case STARTBLINK:
      mexPrintf("start blink");break;
    case STARTSACC:
      mexPrintf("start sacc");break;
    case STARTFIX:
      mexPrintf("start fix");break;
    case STARTSAMPLES:
      mexPrintf("start samples");break;
    case STARTEVENTS:
      mexPrintf("start events");break;
    case STARTPARSE:
      mexPrintf("start parse");break;
    case ENDBLINK:
      mexPrintf("end blink");break;
    case ENDSACC:
      mexPrintf("end sacc");break;
    case ENDFIX:
      mexPrintf("end fix");break;
    case ENDSAMPLES:
      mexPrintf("end samples");break;
    case ENDEVENTS:
      mexPrintf("end events");break;
    case ENDPARSE:
      mexPrintf("end parse");break;
    case FIXUPDATE:
      mexPrintf("fix update");break;
    case BREAKPARSE:
      mexPrintf("break parse");break;
    case BUTTONEVENT:
      mexPrintf("button event");break;
    case INPUTEVENT:
      mexPrintf("input event");break;
    case MESSAGEEVENT:
      mexPrintf("message event");break;
    case SAMPLE_TYPE:
      mexPrintf("sample type");break;
    case RECORDING_INFO:
      mexPrintf("recording info");break;
    case NO_PENDING_ITEMS:
      mexPrintf("no pending items");break;
      break;
  }
  mexPrintf("\n");
}

//////////////////////////
//   isEyeUsedMessage   //
//////////////////////////
int isEyeUsedMessage(int eventType,ALLF_DATA *event)
{
  if (eventType == MESSAGEEVENT) {
    if (strlen(&(event->fe.message->c)) > 8) {
      if (strncmp(&(event->fe.message->c),"EYE_USED",8) == 0) {
	return 1;
      }
    }
  }
  return 0;
}



///////////////////
//   dispEvent   //
///////////////////
void dispEvent(int eventType,ALLF_DATA *event,int verbose)
{
  if (eventType == SAMPLE_TYPE) {
    if (verbose) {
	mexPrintf("(readEDF) Sample eye 0 is %i: pupil [%f %f] head [%f %f] screen [%f %f] pupil size [%f]\n",event->fs.time,event->fs.px[0],event->fs.py[0],event->fs.hx[0],event->fs.hy[0],event->fs.gx[0],event->fs.gy[0],event->fs.pa[0]);
	mexPrintf("(readEDF) Sample eye 1 is %i: pupil [%f %f] head [%f %f] screen [%f %f] pupil size [%f]\n",event->fs.time,event->fs.px[1],event->fs.py[1],event->fs.hx[1],event->fs.hy[1],event->fs.gx[1],event->fs.gy[1],event->fs.pa[1]);
      }
  }
}


