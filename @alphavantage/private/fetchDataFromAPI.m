% Fetch data for a single symbol via the API url
function data = fetchDataFromAPI(url, timeout, contentType)
    % query the webserver, report error (if any)
    options = weboptions('Timeout',timeout, 'CertificateFilename','');
    %options.ContentType = contentType; %always use 'auto' otherwise API errors will not be trapped
    %options.Debug = true;  % displays HTTP connection log
    inputData = webread(url, options);
    if ischar(inputData)  % if data is ok inputData will normally be a struct or byte array
        error('MATLAB:AlphaVantage:ErrMsg','Error reported by AlphaVantage API: %s', inputData);
    end
    if strcmpi(contentType,'table')
        % Check for an AV error msg (reported within a struct field)
        if isstruct(inputData)
            fields = fieldnames(inputData);
            msg = inputData.(fields{1});
            error('MATLAB:AlphaVantage:ErrMsg','Error reported by AlphaVantage API: %s', msg);
        end
        % Save the inputData into a temporary CSV file
        inputText = char(inputData)';
        filename = [tempname '.csv'];
        fid = fopen(filename,'w');
        fwrite(fid, inputText, 'char');
        fclose(fid);
        % Load the CSV data as a Matlab table
        data = readtable(filename);
        % Delete the temporary CSV file
        delete(filename);
    else
        % Parse the returned inputData to extract the returned data struct
        data = parseSubStruct(inputData);
    end
end

% Parse JSON sub-struct
function data = parseSubStruct(data)
    if ~isstruct(data) || isempty(data), return, end  % early bail-out: unexpected input
    mainFields = fieldnames(data);
    if numel(mainFields) == 0  % early bail-out: unexpected input
        return
    elseif numel(mainFields) == 1
        %auto-drill inward in case of only one field
        data = data.(mainFields{1});
        if ischar(data)  % if data is ok inputData will be a struct
            error('MATLAB:AlphaVantage:ErrMsg','Error reported by AlphaVantage API: %s', data);
        end
    end
    dataFields = fieldnames(data);
    outData = struct;  % initialize
    for fieldsIdx = 1 : numel(dataFields)
        inField = dataFields{fieldsIdx};
        inData   = normalizeFieldData(data.(inField));
        outField = normalizeFieldname(inField);
        if strcmpi(outField,'TimeSeries')
            inData = normalizeTimeSeries(inData);
        end
        outData.(outField) = inData;
    end
    data = outData;
end

% Normalize reported field name
function fieldname = normalizeFieldname(fieldname)
    fieldname = regexprep(fieldname, '^x\d+_(\D)', '$1');     %exclude leading numeral (but not date/time)
    fieldname = regexprep(fieldname, '_$', '');               %exclude trailing '_'
    fieldname = regexprep(fieldname, '(TimeSeries).*', '$1'); %exclude interval
end

% Normalize reported field data
function data = normalizeFieldData(data)
    if ischar(data)  % field data are usually chars, but check just in case...
        data = regexprep(data, '%$', '');  % strip trailing '%' (percent fields)
        newData = str2double(data);
        if ~isnan(newData)
            data = newData;
        end
    elseif isstruct(data)
        data = parseSubStruct(data);
    end
end

% Normalize time-series data (multi-date fields => struct array)
function outData = normalizeTimeSeries(inData)
    outData = struct;  % initialize
    datetimes = fieldnames(inData);
    for datetimeIdx = numel(datetimes) : -1 : 1  % reversed to preallocate
        % First add the date/time fields
        datetimeStr = datetimes{datetimeIdx};
        switch length(datetimeStr)
            case 11   % xyyyy_mm_dd
                dateStr = [datetimeStr(2:5)   '-' datetimeStr(7:8)   '-' datetimeStr(10:11)];
            otherwise % xyyyy_mm_ddHH_MM_SS
                dateStr = [datetimeStr(2:5)   '-' datetimeStr(7:8)   '-' datetimeStr(10:11) ...
                           datetimeStr(12:13) ':' datetimeStr(15:16) ':' datetimeStr(18:19)];
        end
        dateTime = datetime(dateStr);
        outData(datetimeIdx).timestamp = dateTime;
        %outData(datetimeIdx).datestr  = dateStr;
        %outData(datetimeIdx).datenum  = datenum(dateTime);

        % Now append the data fields
        thisData = inData.(datetimeStr);
        dataFields = fieldnames(thisData);
        for fieldIdx = 1 : numel(dataFields)
            thisField = dataFields{fieldIdx};
            outData(datetimeIdx).(thisField) = thisData.(thisField);
        end
    end
end
