% HISTORY - Get historic OHLCV data bars for the specified security symbol
%
% Syntax:
%
%   data = history(C, SYMBOL, STARTDATETIME, ENDDATETIME, PERIODICITY)
%
% Input arguments:
%
%   C             - Alphavantage connector object created using the alphavantage() constructor function
%   SYMBOL        - A single security symbol (char array or string). 
%                   This is a mandatory input argument
%   STARTDATETIME - Earliest bar date/time to return (datetime object, date number, string, or char array).
%                   This is an optional input argument
%   ENDDATETIME   - Latest   bar date/time to return (datetime object, date number, string, or char array).
%                   This is an optional input argument
%   PERIODICITY   - Data bar size (char array or string). One of: 
%                   1min, 5min, 15min, 30min, hour, day, week, month, quarter, year
%                   This is an optional input argument
%
% Output value:
%
%   data - historic data, in a format that depends on the OutputFormat object property (default: 'timetable')
%
% Usage examples:
%
%   1. Request non-adjusted daily historical data bars for the specified symbol:
%
%        >> c = alphavantage(...);  % create an API connector object
%        >> data = c.history('FB')  % or: history(c,'FB')
%
%      returns:
%
%        data =
%          100×5 timetable
%             timestamp     open      high      low    close    volume 
%             __________  ________  ________  _______  ______  ________
%             2021-07-29       361    365.52   356.74  358.32  32210926
%             2021-07-28    374.56  377.5499   366.93  373.28  29676910
%             2021-07-27    371.91    373.15   364.55  367.81  15705447
%             2021-07-26    369.58    374.44   368.22  372.46  14925222
%             2021-07-23    360.91    375.33   357.19  369.79  33694328
%             2021-07-22    346.68    351.54   345.21  351.19  12385441
%             2021-07-21     341.5    346.52   341.25  346.23   9279657
%             ...
% 
%   2. Request adjusted daily historical data bars for the specified symbol:
%
%        >> c.Adjusted = true;      % return adjusted historic data from now on
%        >> data = c.history('FB')
%
%      returns:
%
%        data =
%          100×5 timetable
%             timestamp     open      high      low    close   adjusted_close   volume   dividend_amount  split_coefficient
%             __________  ________  ________  _______  ______  ______________  ________  _______________  _________________
%             2021-07-29       361    365.52   356.74  358.32      358.32      32210926         0                 1
%             2021-07-28    374.56  377.5499   366.93  373.28      373.28      29676910         0                 1
%             2021-07-27    371.91    373.15   364.55  367.81      367.81      15705447         0                 1
%             2021-07-26    369.58    374.44   368.22  372.46      372.46      14925222         0                 1
%             2021-07-23    360.91    375.33   357.19  369.79      369.79      33694328         0                 1
%             2021-07-22    346.68    351.54   345.21  351.19      351.19      12385441         0                 1
%             2021-07-21     341.5    346.52   341.25  346.23      346.23       9279657         0                 1
%             ...
% 
%   3. Request intraday historical data bars using Parallel Computing Toolbox:
% 
%        >> c.UseParallel = true;  % Use PCT parallelization, if available
%        >> data = c.history('FB', '2020-06-27', '2020-10-23', '30min');
% 
% Additional information: 
%
%   intraday - https://www.alphavantage.co/documentation/#intraday-extended
%   daily+   - https://www.alphavantage.co/documentation/#dailyadj
%
% See also: alphavantage, quotes
function data = history(obj, symbol, startDateTime, endDateTime, periodicity, varargin)

    %% Parse the input args
    narginchk(2,inf);  % only symbol input arg is mandatory, the rest are optional

    % Parse and check the string input arg
    symbol = str2char(symbol);
    if iscell(symbol) || any(symbol==' ' | symbol==',')
        error('MATLAB:AlphaVantage:HistorySymbol','AlphaVantage history query expects a single symbol as input');
    end
    validateattributes(symbol, {'char','string'}, {'nonempty'}, 'alphavantage.history()', 'symbol',1);

    % Parse and check the start/end date/time input args
    oldWarn = warning('off','MATLAB:structOnObject');
    optionalArgNames = fieldnames(struct(obj));
    warning(oldWarn);
    if nargin < 3,  startDateTime = [];      end
    if nargin < 4,  endDateTime = datetime;  end  % =now
    if nargin < 5
        periodicity = 'day';

        % Check whether startDateTime,endDateTime args were used for P-V args
        if ischar(startDateTime) && any(strcmpi(startDateTime,optionalArgNames))
            obj.(startDateTime) = endDateTime;
            startDateTime = [];
            endDateTime   = [];
        end
    elseif mod(nargin,2) == 1
        % Check whether endDateTime,periodicity args were used for P-V args
        if ischar(endDateTime) && any(strcmpi(endDateTime,optionalArgNames))
            obj.(endDateTime) = periodicity;
            endDateTime = [];
            periodicity = 'day';
        end
    else
        % periodicity input arg must be the name of an optional P-V arg
        obj.(periodicity) = varargin{1};
        periodicity = 'day';
        varargin(1) = [];

        % Check whether startDateTime,endDateTime args were used for P-V args
        if ischar(startDateTime) && any(strcmpi(startDateTime,optionalArgNames))
            obj.(startDateTime) = endDateTime;
            startDateTime = [];
            endDateTime   = [];
        end
    end
    startDateTime = parseDateTime(startDateTime);
    endDateTime   = parseDateTime(endDateTime);

    % Parse and check the periodicity (interval) input arg
    validateattributes(periodicity, {'char','string'}, {'nonempty'}, 'alphavantage.history()', 'periodicity',1);
    periodicity = lower(regexprep(char(periodicity),'\s','')); %destring, strip whitespaces
    periodicity = regexprep(periodicity,'(\d.+)s$','$1');  % fix a common usage mistake...
    periodicity = regexprep(periodicity,'1hour','60min');  % fix a common usage mistake...
    % Note: we deliberately do NOT assert that periodicity is one of
    % {'1min','5min','15min','30min','hour','day','week','month',...},
    % just in case AV adds new possible values sometime in the future

    % Assume that any periodicity that starts with a number is intra-day in order to
    % avoid checking specific periodicity values (that AV might change in the future)
    %isIntraday = any(strcmpi(periodicity, {'1min','5min','15min','30min','60min'}));
    isIntraday = periodicity(1) >= '1' && periodicity(1) <= '9';

    % Process the optional P-V input args (if specified by the user)
    obj.parseOptionalInputArgs(varargin{:});

    %% Prepare the API query URL for the specified symbol
    if isIntraday  % intra-day, parallelizable over the monthly slices
        endPoint = 'TIME_SERIES_INTRADAY_EXTENDED';
        intradayParams = ['&adjusted=' mat2str(obj.Adjusted) '&slice='];
        intradaySlices = getIntradaySlices(startDateTime, endDateTime);
    else  % daily (EOD) data, not parallelizable
        if obj.Adjusted
            endPoint = 'TIME_SERIES_DAILY_ADJUSTED';
        else
            endPoint = 'TIME_SERIES_DAILY';
        end
        intradayParams = '';
        intradaySlices = {''};
    end
    simulatedPeriodicities = {'week','month','quarter','year'};
    if obj.MaxItems > 100 || any(strcmpi(periodicity,['day',simulatedPeriodicities]))
        outputSize = 'full';
    else
        outputSize = 'compact';
    end
    url = [obj.URL '/query?function=' endPoint ...
                   '&apikey='     obj.API_Key ...
                   '&interval='   periodicity ...
                   '&outputsize=' outputSize ...
                   '&symbol=' symbol ...
                   '&datatype=csv' ...
                   intradayParams];

    %% Query the API using the prepared URL
    numSlices = numel(intradaySlices);
    data = cell(1, numSlices);  % initialize
    timeout = obj.Timeout;
    contentType = 'table';
    if obj.UseParallel && numSlices > 1
        parfor (sliceIdx = 1 : numSlices, numSlices)
            % Fetch the latest quote data for this symbol
            % note: use sub-function rather than class method to reduce data transfer to workers
            %data{symbolIdx} = obj.fetchSymbolQuote(symbols{symbolIdx});
            data{sliceIdx} = fetchDataFromAPI([url intradaySlices{sliceIdx}], timeout, contentType);
        end
    else  % don't parallelize, even if the user has PCT installed
        for sliceIdx = 1 : numSlices
            % Fetch the latest quote data for this symbol
            data{sliceIdx} = fetchDataFromAPI([url intradaySlices{sliceIdx}], timeout, contentType);
        end
    end
    try data = vertcat(data{:}); catch, end % convert into a struct array (if all data elements match)

    %% Post-process the results based on date/time and periodicity args
    % If start/end date/time was specified, filter the data accordingly
    data = filterStartEndTimes(data, startDateTime, endDateTime);

    % If the requested periodicity is simulated, apply it now
    % Note: AV's API natively supports only periodicities up to 1 day,
    % so longer intervals need to be simulated in code here
    if any(strcmpi(periodicity, simulatedPeriodicities))
        data = applyPeriodicity(data, periodicity);
    end

    %% Format the output data based on the requested OutputFormat
    data = obj.formatOutputData(data, true);
end

%% Various utility functions
% parseDateTime - Parse input date/time value into a MATLAB datetime object
function value = parseDateTime(value)
    if isempty(value)
        return
    elseif isnumeric(value) && value > 7e5 && value < 8e5  % looks like a relevant datenum
        value = datetime(value,'ConvertFrom','datenum');
    elseif ischar(value) || isa(value,'string')
        value = datetime(value);
    elseif ~isdatetime(value)
        error('MATLAB:AlphaVantage:Datetime','Start and End date/time values must be in a valid datetime format')
    end
end

% Filter data based on start/end datetime (if specified)
function data = filterStartEndTimes(data, startDateTime, endDateTime)
    % data is assumed to be a table here
    if isempty(data) || ~isa(data,'table'),  return,  end
    try
        datetimes = data.timestamp;
    catch
        datetimes = data.time;
    end
    if ~isempty(startDateTime)
        invalidIdx = datetimes < startDateTime;
        data(invalidIdx, :) = [];
        datetimes(invalidIdx) = [];
    end
    if isempty(data),  return,  end
    if ~isempty(endDateTime)
        if endDateTime==dateshift(endDateTime,'start','day')
            endDateTime = endDateTime + 0.99998; %include entire endDateTime day's data
        end
        data(datetimes > endDateTime, :) = [];
    end
end

% Simulated periodicity processing
function newData = applyPeriodicity(data, periodicity)
    % data is assumed to be a table here
    if ~isa(data,'table'),  return,  end
    try
        datetimes = data.timestamp;
    catch
        datetimes = data.time;
    end
    maxDatetime = max(datetimes);
    periodTimes = dateshift(datetimes,'end',periodicity);
    periodTimes(periodTimes>maxDatetime) = maxDatetime;
    periodDatenums = datenum(periodTimes);
    periodLastDayIdx = find(diff([1;periodDatenums]));
    newData = data(periodLastDayIdx,:);
    newData.volume = flip(groupsummary(data.volume,periodTimes,'sum'));
    try
        newData.volume = flip(groupsummary(data.volume,periodTimes,'sum'));
    catch  % probably R2017b or older (no groupsummary function)
        allVolumes = data.volume;
        numPeriods = numel(periodLastDayIdx);
        for idx = 1 : numPeriods
            startIdx = periodLastDayIdx(idx);
            if idx < numPeriods
                endIdx = periodLastDayIdx(idx+1)-1;
            else
                endIdx = numel(allVolumes);
            end
            newData.volume(idx) = sum(allVolumes(startIdx:endIdx));
        end
    end
end

% Get monthly slice names based on the requested start/end datetimes
function slices = getIntradaySlices(startDateTime, endDateTime)
    % Compose a cell array of 24 monthly slice names for the past 2 years
    [allYears, allMonths] = meshgrid(1:2, 1:12);
    slices = compose('year%dmonth%d', allYears(:), allMonths(:)); %24 slices: year1month1,year1month2,...,year2month12
    N = numel(slices);  %=24

    % Remove slices that start after the requested endDateTime or end before the requested startDateTime
    if isempty(startDateTime), startDateTime = datetime - years(2); end  % =2 years ago
    if isempty(endDateTime),   endDateTime   = datetime; end  % =now
    monthStarts = datetime+1 - calmonths(1:24); %=dateshift(datetime,'start','month') - calmonths(0:23);
    monthEnds   = datetime   - calmonths(1:24); %=dateshift(datetime,'end',  'month') - calmonths(0:23);
    % Note: AV's mothly slice boundaries are inaccurate, so request extra slice before/after
    %slices(monthStarts>endDateTime | monthEnds<startDateTime) = [];
    startMonthIdx = max([1, find(monthStarts>endDateTime,1,'last')]);
    endMonthIdx   = min([N, find(monthEnds<startDateTime,1)]);
    slices = slices(startMonthIdx : endMonthIdx);
end
