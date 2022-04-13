% ALPHAVANTAGE wrapper class stores an API key and provides calls to AlphaVantage
% API that mirror other connectors in the MATLAB Data-Feed Toolbox
%
% Additional information: https://www.alphavantage.co/documentation

% Copyright 2021 The MathWorks, Inc.

classdef (CaseInsensitiveProperties) alphavantage < handle

    properties
        Timeout      (1,1) double {mustBePositive} = 5  % Timeout value in seconds for data queries (default=5)
        URL          (1,:) char = 'https://www.alphavantage.co'  % API endpoint, used in case AlphaVantage changes its endpoints (default='https://www.alphavantage.co')
        Adjusted     (1,1) logical = true  % Adjust historic data for splits/dividends? (default=true)
        UseParallel  (1,1) logical = false % Use PCT for parallelizable API queries? (default=false)
        MaxItems     (1,1) double {mustBePositive,mustBeInteger} = 100  % Maximum number of data bars to return (default=100)
        OutputFormat (1,:) char {mustBeMember(OutputFormat,{'struct','table','timetable'})} = 'timetable'  % Format of returned output data (default='timetable')
    end

    properties (Access = private)
        API_Key      (1,:) char  % User-specific API key, created by AlphaVantage
    end

    methods
        %% Constructor
        % obj = alphavantage(API_Key, timeout, url)
        function obj = alphavantage(API_Key, timeout, url)
            % ALPHAVANTAGE Class constructor method (input arguments: API_Key, Timeout, URL)
            %
            % Syntax:
            %
            %   C = alphavantage(API_KEY) 
            %   C = alphavantage(API_KEY, TIMEOUT) 
            %   C = alphavantage(API_KEY, TIMEOUT, URL) 
            %
            % Input arguments:
            %
            %   API_KEY - User-specific API key, provided by AlphaVantage, or path of a text file that contains this key
            %   TIMEOUT - Timeout value in seconds uses when making data requests (default=5)
            %   URL     - API endpoint, used in case AlphaVantage changes its endpoints (default='https://www.alphavantage.co')
            %
            % Output value:
            %
            %   C - an alphavantage connector object
            %
            % Description:
            %
            %   C = alphavantage(API_KEY) creates an AlphaVantage connection object
            %   and uses the given API_KEY for all subsequent data requests. 
            % 
            %   C = alphavantage(filename) creates an AlphaVantage connection object
            %   and uses the API_KEY contained in the specified filename for all
            %   subsequent data requests. 
            % 
            %   C = alphavantage(API_KEY, TIMEOUT) creates an AlphaVantage connection
            %   object with a specific Timeout value for all subsequent data queries
            %   (default value: 5 [seconds]).
            % 
            %   C = alphavantage(API_KEY, TIMEOUT, URL) creates an AlphaVantage connection
            %   object with a specific Timeout value and a non-standard root URL
            %   for AlphaVantage's service (default value: 'https://www.alphavantage.co').
            %
            % Usage examples:
            %
            %   1. Make a connection with a valid API_KEY:
            %
            %        >> c = alphavantage("12345!@#$%")
            %
            %      returns:
            %
            %        c = 
            %          alphavantage with properties:
            %
            %            Timeout: 5
            %                URL: 'https://www.alphavantage.co'
            %           Adjusted: 1
            %        UseParallel: 0
            %           MaxItems: 100
            %       OutputFormat: 'timetable'
            % 
            %   2. Attempt to connect with a bad API_KEY:
            % 
            %        >> c = alphavantage("this is a bad API key!")
            % 
            %      results in an error:
            % 
            %        Error using alphavantage
            %        Cannot connect to AlphaVantage using the specified API key. 
            %        Please visit https://www.alphavantage.co/support/#api-key to get a valid AlphaVantage API key.
            %
            % Additional information: https://www.alphavantage.co/documentation
            %
            % See also: history, quotes

            %% Parse input args
            if nargin < 1  % API_Key not provided
                error('MATLAB:AlphaVantage:API_Key', 'API_Key must be specified to connect to AlphaVantage')
            end
            if exist(API_Key,'file')  % filename provided rather than direct API key
                [fid, errMsg] = fopen(API_Key,'rt');
                if fid < 0
                    error('MATLAB:AlphaVantage:API_Key', 'Cannot read AlphaVantage API key from %s: %s', API_Key, errMsg);
                end
                API_Key = strtrim(strtok(char(fread(fid,'*char')')));
                fclose(fid);
            end
            obj.API_Key = API_Key;

            if nargin > 1  % Timeout specified
                obj.Timeout = timeout;
            end

            if nargin > 2  % URL specified
                obj.URL = url;
            end

            %% Connect to AV and download some data to test the connection
            try
                obj.quotes('MSFT');
            catch err
                error('MATLAB:AlphaVantage:Connect', 'Cannot connect to AlphaVantage using the specified API key. Please visit https://www.alphavantage.co/support/#api-key to get a valid AlphaVantage API key.')
            end
        end
    end

    methods (Access='private')
        %% Optional input args processing
        function parseOptionalInputArgs(obj, varargin)
            for idx = 1 : 2 : nargin-1
                propName  = varargin{idx};
                propValue = varargin{idx+1};
                obj.(propName) = propValue; 
            end
        end

        %% Fetch latest quote for a single symbol
        function data = fetchSymbolQuote(obj, symbol)
            % Prepare the query URL
            url = [obj.URL '/query?function=GLOBAL_QUOTE&symbol=' symbol '&apikey=' obj.API_Key];

            % query the webserver, report error (if any)
            options = weboptions('Timeout',obj.Timeout, 'CertificateFilename','');
            options.ContentType = 'auto';
            inputData = webread(url, options);
            if ischar(inputData)  % if data is ok inputData will be a struct
                error('MATLAB:AlphaVantage:ErrMsg','Error reported by AlphaVantage API: %s', inputData);
            end

            % Parse the returned inputData to extract the returned data struct
            data = parseSubStruct(inputData);
        end

        %% Output format parsing
        function data = formatOutputData(obj, data, hasDateTimes)
            if isstruct(data)
                % Limit the number of data bars as specified
                data = data(1:min(end,obj.MaxItems));
                try data.TimeSeries = data.TimeSeries(1:min(end,obj.MaxItems)); catch, end

                % Convert to table/timetable if requested
                try
                    hasDateTimes = nargin > 2 && hasDateTimes;
                    switch obj.OutputFormat
                        case {'table','timetable'}
                            try data = data.TimeSeries; catch, end
                            data = struct2table(data,'AsArray',true);
                            if hasDateTimes && strcmpi(obj.OutputFormat,'timetable')
                                data = table2timetable(data); %,'RowTimes',dateTimes);  % automatically use 1st data field as timetable
                            end
                        otherwise
                            return  % leave data as-is (struct format)
                    end
                catch
                    warning('MATLAB:AlphaVantage','Cannot convert output data to %s format',obj.OutputFormat);
                end

            elseif isa(data,'table')

                % Limit the number of data bars as specified
                data = data(1:min(end,obj.MaxItems),:);

                % Convert to struct/timetable if requested
                try
                    switch obj.OutputFormat
                        case 'timetable'
                            data = table2timetable(data); %,'RowTimes',dateTimes);  % automatically use 1st data field as timetable
                        case 'struct'
                            data = table2struct(data);
                        otherwise
                            return  % leave data as-is (table format)
                    end
                catch
                    warning('MATLAB:AlphaVantage','Cannot convert output data to %s format',obj.OutputFormat);
                end
            end
        end
    end
end
