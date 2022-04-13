% QUOTES - Get the latest market quote for the specified security symbol(s)
%
% Syntax:
%
%   data = quotes(C, SYMBOLS)
%
% Input arguments:
%
%   C          - Alphavantage connector object created using the alphavantage() constructor function
%   SYMBOLS    - One or more security symbols, specified as MATLAB char array, cells of char arrays,
%                string (scalar/array), or a comma-separated list of symbols (e.g. 'FB,MSFT,GOOG').
%                This is a mandatory input argument
%
% Output value:
%
%   data - latest market quotes, based on the optional OutputFormat parameter (default: 'table')
%
% Usage examples:
%
%   1. Request quote for several symbols:
%
%        >> c = alphavantage(...);  % create an API connector object
%        >> data = c.quotes('IBM,FB,TSLA')  % or: c.quotes({'IBM','FB','TSLA'})
%
%      returns:
%
%        data =
%          3×10 table
%             Symbol    Open    High    Low    Price    Volume   LatestTradingDay  PreviousClose  Change  ChangePercent
%            ________  ______  ______  ______  ______  ________  ________________  _____________  ______  _____________
%            {'IBM' }  142.33  142.96   141.6  141.93   2657669   {'2021-07-29'}      141.77        0.16      0.1129   
%            {'FB'  }     361  365.52  356.74  358.32  32210926   {'2021-07-29'}      373.28      -14.96     -4.0077   
%            {'TSLA'}  649.79  683.69   648.8  677.35  29688446   {'2021-07-29'}      646.98       30.37      4.6941   
% 
%   2. Request quote for several symbols using Parallel Computing Toolbox:
% 
%        >> c.UseParallel = true;
%        >> data = c.quotes("IBM,FB,TSLA")  % or: c.quotes(["IBM","FB","TSLA"])
%
%   3. Request quotes in struct (not table) format:
%
%        >> c.OutputFormat = "struct";
%        >> data = c.quotes("IBM")  % or: quotes(c,"IBM")
%
%      returns:
%
%        data = 
%          struct with fields:
% 
%                      Symbol: 'IBM'
%                        Open: 142.33
%                        High: 142.96
%                         Low: 141.6
%                       Price: 141.93
%                      Volume: 2657669
%            LatestTradingDay: '2021-07-29'
%               PreviousClose: 141.77
%                      Change: 0.16
%               ChangePercent: 0.1129
% 
% Additional information: https://www.alphavantage.co/documentation/#latestprice
%
% See also: alphavantage, history
function data = quotes(obj, symbols, varargin)

    %% Parse the input args
    narginchk(2,inf);  % only symbols input arg is mandatory, the rest are optional

    % Parse and check the string input arg
    validateattributes(symbols, {'char','string','cell'}, {'nonempty'}, 'alphavantage.quote()', 'symbols',1);
    symbols = str2char(symbols);
    if ~iscell(symbols), symbols = regexp(symbols,'[, ]','split'); end

    % Process the optional P-V input args (if specified by the user)
    obj.parseOptionalInputArgs(varargin{:});

    %% Query the API for each requested symbol separately
    numSymbols = numel(symbols);
    data = cell(1, numSymbols);  % initialize
    url = [obj.URL '/query?function=GLOBAL_QUOTE&apikey=' obj.API_Key '&symbol='];
    timeout = obj.Timeout;
    contentType = 'auto';
    if obj.UseParallel && numSymbols > 1
        parfor (symbolIdx = 1 : numSymbols, numSymbols)
            % Fetch the latest quote data for this symbol
            % note: use sub-function rather than class method to reduce data transfer to workers
            %data{symbolIdx} = obj.fetchSymbolQuote(symbols{symbolIdx});
            data{symbolIdx} = fetchDataFromAPI([url symbols{symbolIdx}], timeout, contentType);
        end
    else  % don't parallelize, even if the user has PCT installed
        for symbolIdx = 1 : numSymbols
            % Fetch the latest quote data for this symbol
            data{symbolIdx} = fetchDataFromAPI([url symbols{symbolIdx}], timeout, contentType);
        end
    end
    try data = [data{:}]; catch, end % convert into a struct array (if all data elements match)

    %% Format the output data based on the requested OutputFormat
    data = obj.formatOutputData(data);
end
