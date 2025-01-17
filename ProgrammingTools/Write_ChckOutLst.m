% This script reads the an Excel file containing the parameters for an
% Output module and writes some Fortran code containing appropriate
% parameters (which can be imported into the output module).
 
% Users will need to modify the XLS_file variable to point to the location
% of the OutListParameters.xlsx file.
% The FAST Simulation Toolbox must also be in the user's working directory
% (for the function GetOutListParameters)
%..........................................................................

clear all

ModuleName = input('Enter the module for which the output module will be generated (ElastoDyn, ServoDyn, etc.): ','s');

XLS_file  = '../../../../openfast/docs/OtherSupporting/OutListParameters.xlsx';
OutListSheet = ModuleName;
addErrChk = false;

if strfind(ModuleName,'_Nodes')
    ModuleName = strrep(ModuleName,'_Nodes','');
    
    PrefixStr1= 'BldNdOuts_';
    PrefixStr2= 'BldNd_';
    NodalOutputs=true;
    StartIndx='1';
else
    PrefixStr1='';
    PrefixStr2='';
    NodalOutputs=false;
    StartIndx='0';
end


switch ModuleName
    case 'ElastoDyn'
        ModName = 'ED';
    case 'ServoDyn'
        ModName = 'SrvD';
        addErrChk = true;  %there is only one check
    case 'InflowWind'
        ModName = 'InflowWind';
    case 'AeroDyn'
        ModName = 'AD';
    case 'BeamDyn'
        ModName = 'BD';
    otherwise
        error( 'Invalid module name.');        
end

      
out_file = [OutListSheet '_SetOutParam.f90'];
mod_file = [OutListSheet '_Parameters.f90'];


%..................


StrName  = 'ChanLen'; %ChanLen is defined in the NWTC Library
StrNameM = 'OutStrLenM1';

[Category, VarName, InvalidCriteria, ValidInputStr, ValidInputStr_VarName, ValidInputStr_Units ] = GetOutListParameters( XLS_file, OutListSheet );


%% The list of output names that are valid in the Module input file

[SORTedNames, IX] = sort( upper( ValidInputStr ) );      %just in case it's not upper case or sorted (but make sure you store the indices!) SORTedNames = SORTName(IX);
SORTedNames       = char( SORTedNames );                 %stored as a string array (with padding for FORTRAN)
Sorted_Units      = char( ValidInputStr_Units(IX) );     %stored as a string array (with padding for FORTRAN)

[nr, CLen_Var] = size(SORTedNames);
[nr2,CLen_Unit] = size(Sorted_Units);

fprintf( 'Channels are %2.0f characters long.\n', max(CLen_Var+1,CLen_Unit) );

numPerR  = floor(100 / (3+max(CLen_Var,CLen_Unit))) %7;       %number of parameters per row of code

% .........................................................................
%% write the "VarName"s parameters to the module that defines them
% .........................................................................
[~,tmpFileName,tmpExt] = fileparts(XLS_file);
tmpFileName = [tmpFileName tmpExt];

fout = fopen( mod_file, 'wt' );
fprintf( fout, '%s\n',      '! ===================================================================================================' );
fprintf( fout, '%s\n',      '! NOTE: The following lines of code were generated by a Matlab script called "Write_ChckOutLst.m"' );
fprintf( fout, '%s%s%s\n',  '!      using the parameters listed in the "',tmpFileName,'" Excel file. Any changes to these' );
fprintf( fout, '%s\n',      '!      lines should be modified in the Matlab script and/or Excel worksheet as necessary.');
fprintf( fout, '%s\n',      '! ===================================================================================================' );
fprintf( fout, '%s\n',     ['! This code was generated by Write_ChckOutLst.m at ' datestr(now) '.'] );

% fprintf( fout, '%s\n',        'MODULE Output' );
% fprintf( fout, '\n\n%s\n\n\n','      ! This MODULE stores variables used for output.' );
% fprintf( fout, '%s\n',        '   USE NWTC_Library' );
fprintf( fout, '\n\n%s\n\n',  '     ! Parameters related to output length (number of characters allowed in the output data headers):' );
tmpLen = max(length(StrNameM),length(StrName));
numFmt =  ['   INTEGER(IntKi), PARAMETER      :: %' num2str(tmpLen) 's = '];                                                                
fprintf( fout, [numFmt '%s\n\n'],   [StrNameM, repmat(' ',1,tmpLen-length(StrNameM))], [StrName ' - 1'] );        
fprintf( fout, '\n%s\n',      '     ! Indices for computing output channels:' );
fprintf( fout, '%s\n',        '     ! NOTES:');
fprintf( fout, '%s\n',        '     !    (1) These parameters are in the order stored in "OutListParameters.xlsx"' );
fprintf( fout, '%s\n',        '     !    (2) Array AllOuts() must be dimensioned to the value of the largest output parameter' );
if strcmpi(ModuleName,'FAST')
fprintf( fout, '%s\n',        '     !    (3) If an index (MaxOutPts) ever becomes greater or equal to 1000, the logic to create ARRAY/1 in the FAST-to-ADAMS preprocessor will have to be changed.' );
end

CLen = max(CLen_Var+length(PrefixStr2),length('MaxOutPts'));
numFmtLen = num2str( floor(log10(length(VarName))+1) );
numFmt    =                  ['   INTEGER(IntKi), PARAMETER      :: %' num2str(CLen) 's = %' numFmtLen '.0f\n'];
numFmtN   =                  ['   INTEGER(IntKi), PARAMETER, PUBLIC  :: %' num2str(CLen) 's = %' numFmtLen '.0f\n'];
ParamNum  = 0;

if (~NodalOutputs)
fprintf( fout, '\n%s\n\n',    '     !  Time:' );
fprintf( fout, numFmt,       ['Time' repmat(' ',1,CLen-4)], ParamNum );  %Time is parameter 0; we left justify the character string
end

for i=1:length(VarName)
    if ischar( VarName{i} ) % print the parameter
        ParamNum = ParamNum + 1;
        fprintf( fout, numFmt,  [PrefixStr2 VarName{i}, repmat(' ',1,CLen-length(VarName{i})-length(PrefixStr2))], ParamNum );        
    else
        fprintf( fout, '\n\n%s%s:\n\n',  '     ! ', Category{i});  %make a comment describing the category
    end
end

fprintf( fout, '\n\n%s%s\n',  '     ! ', 'The maximum number of output channels which can be output by the code.');  
if NodalOutputs
    fprintf( fout, numFmtN, [PrefixStr2 'MaxOutPts', repmat(' ',1,CLen-length('MaxOutPts'))], ParamNum );
else
    fprintf( fout, numFmt,  [PrefixStr2 'MaxOutPts', repmat(' ',1,CLen-length('MaxOutPts'))], ParamNum );   
end
% fprintf( fout, '\n\n%s\n\n',  '     ! Regular Variables:' );
% fprintf( fout, ['%s%' numFmtLen '.0f%s\n'],  '   REAL(ReKi)                     :: AllOuts  (0:', ...
%                    ParamNum, ')                               ! An array holding the value of all of the calculated (not selected) output channels.');
% fprintf( fout, ['%s'               '%s\n'],  '   TYPE(OutParmType), ALLOCATABLE :: OutParam (:) ', ...
%                              '                                 ! An array holding names, units, and indices of all of the selected output channels.');
% 
fprintf( fout, '\n%s\n', '!End of code generated by Matlab script');
fprintf( fout, '%s\n',      '! ===================================================================================================' );
fclose(fout);
%%


% .........................................................................
%% Open the file for subroutine that checks if the input OutList contains
% valid entries
% .........................................................................
fout = fopen( out_file, 'wt' );
fprintf( fout, '%s\n', ...
'!**********************************************************************************************************************************', ... 
'! NOTE: The following lines of code were generated by a Matlab script called "Write_ChckOutLst.m"', ...
'!      using the parameters listed in the "OutListParameters.xlsx" Excel file. Any changes to these ' , ...
'!      lines should be modified in the Matlab script and/or Excel worksheet as necessary. ', ...
'!----------------------------------------------------------------------------------------------------------------------------------',...
'!> This routine checks to see if any requested output channel names (stored in the OutList(:)) are invalid. It returns a ',...
'!! warning if any of the channels are not available outputs from the module.',...
'!!  It assigns the settings for OutParam(:) (i.e, the index, name, and units of the output channels, WriteOutput(:)).',...
'!!  the sign is set to 0 if the channel is invalid.',...
'!! It sets assumes the value p%NumOuts has been set before this routine has been called, and it sets the values of p%OutParam here.',...
'!! ',...
['!! This routine was generated by Write_ChckOutLst.m using the parameters listed in OutListParameters.xlsx at ' datestr(now) '.'] );
if strcmp(ModName,'AD')
    fprintf( fout, '%s\n', ...
    ['SUBROUTINE ' PrefixStr1, 'SetOutParam(' PrefixStr2 'OutList, p, p_' ModName ', ErrStat, ErrMsg )'] );
else
    fprintf( fout, '%s\n', ...
    ['SUBROUTINE ' PrefixStr1, 'SetOutParam(' PrefixStr2 'OutList, p, ErrStat, ErrMsg )'] );
end
fprintf( fout, '%s\n', ...
'!..................................................................................................................................',...
''   ,...
'   IMPLICIT                        NONE',...
'',...
'      ! Passed variables',...
''      ,...
['   CHARACTER(' StrName '),        INTENT(IN)     :: ' PrefixStr2 'OutList(:)                        !< The list of user-requested outputs'] );
if strcmp(ModName,'AD')
    fprintf( fout, '%s\n', ...
    '   TYPE(RotParameterType),    INTENT(INOUT)  :: p                                 !< The module parameters',...
    ['   TYPE(' ModName '_ParameterType),    INTENT(INOUT)  :: p_' ModName '                              !< The module parameters'] );
else
    fprintf( fout, '%s\n', ...
    ['   TYPE(' ModName '_ParameterType),    INTENT(INOUT)  :: p                                 !< The module parameters'] );
end
fprintf( fout, '%s\n', ...
'   INTEGER(IntKi),            INTENT(OUT)    :: ErrStat                           !< The error status code',...
'   CHARACTER(*),              INTENT(OUT)    :: ErrMsg                            !< The error message, if an error occurred',...
''    ,...
'      ! Local variables',...
'',...
'   INTEGER                      :: ErrStat2                                        ! temporary (local) error status',...
'   INTEGER                      :: I                                               ! Generic loop-counting index',...
'   INTEGER                      :: J                                               ! Generic loop-counting index',...
'   INTEGER                      :: INDX                                            ! Index for valid arrays',...
''  );
if (~NodalOutputs)
    fprintf( fout, '%s\n', ...
'   LOGICAL                      :: CheckOutListAgain                               ! Flag used to determine if output parameter starting with "M" is valid (or the negative of another parameter)');
end
fprintf( fout, '%s\n', ...
['   LOGICAL                      :: InvalidOutput(' StartIndx ':' PrefixStr2 'MaxOutPts)                      ! This array determines if the output channel is valid for this configuration'],...
['   CHARACTER(' StrName ')           :: OutListTmp                                      ! A string to temporarily hold OutList(I)'],...
['   CHARACTER(*), PARAMETER      :: RoutineName = "' PrefixStr1 'SetOutParam"'],...
''   );




fprintf( fout, '%s%s%s%s%s\n', ...
 '   CHARACTER(',StrNameM, '), PARAMETER  :: ValidParamAry(', num2str(nr), ') =  (/  &   ! This lists the names of the allowed parameters, which must be sorted alphabetically' );                                 
%  '   CHARACTER(',StrNameM, '), PARAMETER  :: ValidParamAry(', num2str(nr), ') =  (/ character(ChanLen) :: &   ! This lists the names of the allowed parameters, which must be sorted alphabetically' );                                 

for iRow = 1:numPerR:nr
    fprintf( fout, '%s', '                               ' );  %the indent for each line
    lastRow = min(iRow+numPerR-1,nr);
    ContLine = true;
    for iNum = iRow:lastRow
        fprintf( fout, ['"%' num2str(CLen_Var) 's"'], SORTedNames(iNum,:) );
        if iNum < nr
            fprintf( fout, '%s', ',' );
        else
            fprintf( fout, '%s\n', '/)'); %end of array
            ContLine = false;
        end
    end
    
    if ContLine
        fprintf( fout, '%s\n', ' &');
    end

end %iRow

%% The list of parameter names corresponding to the entries in ValidParamAry
Sorted_OutInd = ValidInputStr_VarName(IX);

fprintf( fout, '%s%s%s\n', ...
 '   INTEGER(IntKi), PARAMETER :: ParamIndxAry(', num2str(nr), ') =  (/ &                            ! This lists the index into AllOuts(:) of the allowed parameters ValidParamAry(:)' );                                 

for iRow = 1:numPerR:nr
    fprintf( fout, '%s', '                               ' );  %the indent for each line
    lastRow = min(iRow+numPerR-1,nr);
    ContLine = true;
    for iNum = iRow:lastRow
        fprintf( fout, [' %' num2str(CLen_Var+length(PrefixStr2)) 's '], [PrefixStr2 Sorted_OutInd{iNum}] );
        if iNum < nr
            fprintf( fout, '%s', ',' );
        else
            fprintf( fout, '%s\n', '/)'); %end of array
            ContLine = false;
        end
    end
    
    if ContLine
        fprintf( fout, '%s\n', ' &');
    end
    
end %iRow

%% The units corresponding to the entries in ValidParamAry

% note: these units actually correspond to the unique entries in AllOuts(:),
% but i think it will be easier to implement using this array corresponding
% to ValidParamAry(:) entries


fprintf( fout, '%s%s%s%s%s\n', ...
 '   CHARACTER(',StrName, '), PARAMETER :: ParamUnitsAry(', num2str(nr), ') =  (/  &  ! This lists the units corresponding to the allowed parameters' );                                 
%  '   CHARACTER(',StrName, '), PARAMETER :: ParamUnitsAry(', num2str(nr), ') =  (/ character(ChanLen) :: &  ! This lists the units corresponding to the allowed parameters' );                                 

for iRow = 1:numPerR:nr
    fprintf( fout, '%s', '                               ' );  %the indent for each line
    lastRow = min(iRow+numPerR-1,nr);
    ContLine = true;
    for iNum = iRow:lastRow
        fprintf( fout, ['"%' num2str(CLen_Unit) 's"'], Sorted_Units(iNum,:) );
        if iNum < nr
            fprintf( fout, '%s', ',' );
        else
            fprintf( fout, '%s\n', '/)'); %end of array
            ContLine = false;
        end
    end
    
    if ContLine
        fprintf( fout, '%s\n', ' &');
    end
    
end %iRow

%% add the subroutine initializations
fprintf( fout, '%s\n', ...
'',...
'',...
'      ! Initialize values',...
'   ErrStat = ErrID_None',...
'   ErrMsg = ""',...
'   InvalidOutput = .FALSE.',...
'' );

%% Determine if the entry is valid
if ( addErrChk )
        % remove the blank lines (where new categories start)
    nu = length(VarName);

    fprintf( fout, '%s\n', ...
        '', ...
        '      ! Determine which inputs are not valid',...
        '' ); 
    
    for iRow = 1:nu
        if ischar(VarName{iRow}) && ischar(InvalidCriteria{iRow}) && ~isempty(InvalidCriteria{iRow})
            fprintf( fout, ['%s%' num2str(CLen_Var) 's%s%s%s\n'], ...
               '   InvalidOutput(', VarName{iRow}, ') = ( ', InvalidCriteria{iRow}, ' )' );
        end
    end

    fprintf( fout, '%s\n', '' );
    
else
    fprintf( fout, '%s\n', ...
        '', ...
        '!   ..... Developer must add checking for invalid inputs here: .....',...
        '', ...
        '!   ................. End of validity checking .................',...
        '' );    
end 

%% add the last part of the subroutine
fprintf( fout, '%s\n', ...
'',...
'   !-------------------------------------------------------------------------------------------------',...
'   ! Allocate and set index, name, and units for the output channels',...
'   ! If a selected output channel is not available in this module, set error flag.',...
'   !-------------------------------------------------------------------------------------------------',...
''  ,...
['   ALLOCATE ( p%' PrefixStr2 'OutParam(' StartIndx ':p%' PrefixStr2 'NumOuts) , STAT=ErrStat2 )'],...
'   IF ( ErrStat2 /= 0_IntKi )  THEN',...
['      CALL SetErrStat( ErrID_Fatal,"Error allocating memory for the ' ModuleName ' ' PrefixStr2 'OutParam array.", ErrStat, ErrMsg, RoutineName )'],...
'      RETURN',...
'   ENDIF',...
''   );

if (~NodalOutputs) %and strcmp(StartIndx,'0')
fprintf( fout, '%s\n', ...
'      ! Set index, name, and units for the time output channel:',...
''   ,...
'   p%OutParam(0)%Indx  = Time',...
'   p%OutParam(0)%Name  = "Time"    ! OutParam(0) is the time channel by default.',...
'   p%OutParam(0)%Units = "(s)"',...
'   p%OutParam(0)%SignM = 1',...
''   );
end

fprintf( fout, '%s\n', ...
''   ,...
'      ! Set index, name, and units for all of the output channels.',...
'      ! If a selected output channel is not available by this module set ErrStat = ErrID_Warn.',...
''   ,...
['   DO I = 1,p%' PrefixStr2 'NumOuts'],...
''   ,...
['      p%' PrefixStr2 'OutParam(I)%Name  = ' PrefixStr2 'OutList(I)'],...
['      OutListTmp          = ' PrefixStr2 'OutList(I)'] ); %,...

if (~NodalOutputs) %and strcmp(StartIndx,'0')
fprintf( fout, '%s\n', ...
''   ,...
'      ! Reverse the sign (+/-) of the output channel if the user prefixed the',...
'      !   channel name with a "-", "_", "m", or "M" character indicating "minus".',...
''   ,...
''   ,...
'      CheckOutListAgain = .FALSE.',...
''   ,...
'      IF      ( INDEX( "-_", OutListTmp(1:1) ) > 0 ) THEN',...
['         p%' PrefixStr2 'OutParam(I)%SignM = -1                         ! ex, "-TipDxc1" causes the sign of TipDxc1 to be switched.'],...
'         OutListTmp          = OutListTmp(2:)',...
'      ELSE IF ( INDEX( "mM", OutListTmp(1:1) ) > 0 ) THEN ! We''ll assume this is a variable name for now, (if not, we will check later if OutListTmp(2:) is also a variable name)',...
'         CheckOutListAgain   = .TRUE.',...
['         p%' PrefixStr2 'OutParam(I)%SignM = 1'],...
'      ELSE',...
['         p%' PrefixStr2 'OutParam(I)%SignM = 1'],...
'      END IF',...
''     ,...
'      CALL Conv2UC( OutListTmp )    ! Convert OutListTmp to upper case',...
''   ,...
''   ,...
['      Indx = IndexCharAry( OutListTmp(1:' StrNameM '), ValidParamAry )'],...
''      ,...
'',...
'         ! If it started with an "M" (CheckOutListAgain) we didn''t find the value in our list (Indx < 1)',...
''         ,...
'      IF ( CheckOutListAgain .AND. Indx < 1 ) THEN    ! Let''s assume that "M" really meant "minus" and then test again',...
['         p%' PrefixStr2 'OutParam(I)%SignM = -1                     ! ex, "MTipDxc1" causes the sign of TipDxc1 to be switched.'],...
'         OutListTmp          = OutListTmp(2:)',...
'',...
['         Indx = IndexCharAry( OutListTmp(1:' StrNameM '), ValidParamAry )'],...
'      END IF',...
''            ,...
''      ); %,...
else
fprintf( fout, '%s\n', ...
['      p%' PrefixStr2 'OutParam(I)%SignM = 1   ! this won''t be used' ],...
''     ,...
'      CALL Conv2UC( OutListTmp )    ! Convert OutListTmp to upper case',...
''   ,...
''   ,...
['      Indx = IndexCharAry( OutListTmp(1:' StrNameM '), ValidParamAry )'],...
''      ); %,...   
end

fprintf( fout, '%s\n', ...
'      IF ( Indx > 0 ) THEN ! we found the channel name',...
'         IF ( InvalidOutput( ParamIndxAry(Indx) ) ) THEN  ! but, it isn''t valid for these settings',...
['            p%' PrefixStr2 'OutParam(I)%Indx  = 0                 ! pick any valid channel (I just picked "Time=0" here because it''s universal)'],...
['            p%' PrefixStr2 'OutParam(I)%Units = "INVALID"'],...
['            p%' PrefixStr2 'OutParam(I)%SignM = 0'],...
'         ELSE',...
['            p%' PrefixStr2 'OutParam(I)%Indx  = ParamIndxAry(Indx)'],...
['            p%' PrefixStr2 'OutParam(I)%Units = ParamUnitsAry(Indx) ! it''s a valid output'],...
'         END IF',...
'      ELSE ! this channel isn''t valid',...
['         p%' PrefixStr2 'OutParam(I)%Indx  = 0                    ! pick any valid channel (I just picked "Time=0" here because it''s universal)'],...
['         p%' PrefixStr2 'OutParam(I)%Units = "INVALID"'            ],...
['         p%' PrefixStr2 'OutParam(I)%SignM = 0                    ! multiply all results by zero'],...
''         ,...
['         CALL SetErrStat(ErrID_Fatal, TRIM(p%' PrefixStr2 'OutParam(I)%Name)//" is not an available output channel.",ErrStat,ErrMsg,RoutineName)'],...
'      END IF',...
''      ,...
'   END DO',...
''   ,...
'   RETURN',...
['END SUBROUTINE ' PrefixStr1 'SetOutParam'],...
'!----------------------------------------------------------------------------------------------------------------------------------',...
'!End of code generated by Matlab script', ...
'!**********************************************************************************************************************************' );
%% Close the file
fclose(fout);

%% warn when too many outputs have been created!
fprintf( '%s%s%s\n', 'There are ', num2str(ParamNum), ' output parameters.');
if strcmpi(ModuleName,'FAST') && ParamNum >= 1000
    error('Too many output parameters! The maximum for FAST2ADAMS datasets is 1000.')
end    
                                