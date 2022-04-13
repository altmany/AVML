% Convert a possible string => char
function value = str2char(value)
    try
        value = controllib.internal.util.hString2Char(value);
    catch
        if isa(value,'string')
            if numel(value) < 2  % scalar String => char
                value = char(value);
            else  % String array => cell-array of chars
                try
                    value = cellstr(value);
                catch
                    value = arrayfun(@char, value, 'UniformOutput',false);
                end
            end
        end
    end
end
