classdef ads1015 < handle %& matlab.mixin.CustomDisplay
    %ads1015 Analog-to-Digital converter.
    %
    % adc = ads1015(rpi, bus) creates a ads1015 ADC object attached to the
    % specified I2C bus. The first parameter, rpi, is a raspi object. The
    % I2C address of the ads1015 ADC defaults to '0x48'.
    %
    % adc = ads1015(rpi, bus, address) creates a ads1015 ADC object
    % attached to the specified I2C bus and I2C address. Use this form if
    % the ADDR pin is used to change the I2C address of the ads1015 from
    % the default '0x48' to something else.
    %
    % [voltage, rawData] = readVoltage(adc, AINp) reads the single-ended voltage measurement
    % from AINp input port. Also returns the contents of conversion
    % register, optionally in rawData
    % Accepted values for AINp are 0,1,2,3.
    %
    % [voltage, rawData] = readVoltage(adc, AINp, AINn) reads the differential voltage
    % measurement between AINp and AINn input ports. Also returns the
    % contents of conversion register, optionally in rawData
    % Supported differential measurement pairs: (0, 1), (0, 3), (1, 3), (2, 3).
    %
    %
    % Customizable properties of ads1015 given below:
    %
    % The "OperatingMode" property of the ads1015 ADC object determines power
    % consumption, speed and accuracy. The default OperatingMode is
    % 'single-shot' meaning that the ads1015 performs a single analog to
    % digital conversion upon request and goes to power save mode. In
    % continuous mode, the device performs continuous conversions.
    %
    % The "SamplesPerSecond" property sets the conversion rate. 
    %
    % The "VoltageScale" property of the ads1015 ADC object determines the
    % setting of the Programmable Gain Amplifier (PGA) value applied before
    % analog to digital conversion. See table below to correlate the
    % input voltage scale with the PGA value:
    %
    % VoltageScale | PGA Value 
    % -------------------------
    %    6.144  |    2/3
    %    4.096  |    1
    %    2.048  |    2  
    %    1.024  |    4   
    %    0.512  |    8   
    %    0.256  |    16   
    %
    % <a href="http://www.ti.com/lit/gpn/ads1015">Device Datasheet</a>
    %
    % NOTE: Do not apply voltages excedding VDD+0.3V to any input pin.
    
    % Copyright 2020 The MathWorks, Inc.
    
    properties (SetAccess = private, GetAccess = public)
        Address = bin2dec('1001000') % Default address 0x48
    end
    
    properties (Access = public)
        OperatingMode
        VoltageScale    
        SamplesPerSecond
    end
    
    properties (Access = private)
        i2cObj
        PGAbits
        AINp
        AINn
        NumInputs = 4
        ConfigReg
    end
    
    properties (Constant, Hidden)
        AvailableSamplesPerSecond = [128, 250, 490, 920, 1600, 2400, 3300]
        AvailableVoltageScale = [6.144, 4.096, 2.048, 1.024, 0.512, 0.256]
        AvailableOperatingMode = {'single-shot', 'continuous'}
    end
    
    properties (Constant, Access = private)
        % Register addresses
        CONVERSION_REG = 0
        CONFIG_REG     = 1
        LOTHRESH_REG   = 2
        HITHRESH_REG   = 3
        
        % Config register bit shifts
        CONFIG_OS_SHIFT        = 15
        CONFIG_MUX_SHIFT       = 12
        CONFIG_PGA_SHIFT       = 9
        CONFIG_MODE_SHIFT      = 8
        CONFIG_DR_SHIFT        = 5
        CONFIG_COMP_MODE_SHIFT = 4
        CONFIG_COMP_POL_SHIFT  = 3
        CONFIG_COMP_LAT_SHIFT  = 2
        CONFIG_COMP_QUE_SHIFT  = 0
        
        
        % 16-bit ADC result needs to be scaled by this value
        ADC_SCALAR = 2^15 - 1
    end
    
    methods
        function obj = ads1015(raspiObj, bus, address)
            % Set I2C address if not using default
            if nargin > 2
                obj.Address = address;
            else
                address = '0x48';
            end
            
            % Set defaults
            %obj.SamplesPerSecond = 1600;       edited 4-6-21
            obj.SamplesPerSecond = 3300;
            %obj.OperatingMode = 'single-shot';  edited 4-6-21
            obj.OperatingMode = 'continuous';
            %obj.VoltageScale = 6.144;           edited 4-6-21        
            obj.VoltageScale = 4.096;
            
            % Initialize config register value
            obj.ConfigReg = uint16(0);
            
            % Create an i2cdev object to talk to ads1015
            obj.i2cObj = i2cdev(raspiObj, bus, address);
            
            %initialize the device
            write(obj.i2cObj,[0,hex2dec('0x06')],'uint8');
            
        end
        
        function [voltage, rawData] = readVoltage(obj, AINp, AINn)
            % [voltage,rawData] = readVoltage(obj, AINp) reads the single-ended input
            % voltage value at channe AINp. 'rawData' contains the content
            % of conversion register
            %
            % voltage = readVoltage(obj, AINp, AINn) reads the input
            % voltage value that is the difference between AINp and AINn.'rawData' 
            % contains the content of conversion register
            validateattributes(AINp, {'numeric'}, ...
                {'scalar', '>=', 0, '<=', obj.NumInputs-1}, '', 'AINp');
            if nargin > 2
                validateattributes(AINn, {'numeric'}, ...
                    {'scalar', '>=', 0, '<=', obj.NumInputs-1}, '', 'AINn');
            else
                AINn = -1;
            end
 
            % Configure ADC and read requested conversion value
            configReg = getConfigReg(obj, AINp, AINn);
            if strcmp(obj.OperatingMode, 'single-shot') || ...
                    (configReg ~= obj.ConfigReg)
                obj.ConfigReg = configReg;
                configureDevice(obj);
            end
            
            % wait for the conversion to complete
            %pause(1/obj.SamplesPerSecond+0.05); % extra 5msec buffer
            pause(1/obj.SamplesPerSecond); % extra 5msec buffer
            
            %% Read raw ADC conversion value and convert to voltage
            
            % Set the Address Pointer Register to Conversion Register
            write(obj.i2cObj, obj.CONVERSION_REG,'uint8');
            % Read the Higher byte of the conversion register
            dataHigh = read(obj.i2cObj, 1, 'uint8');
            % Read the Lower byte of the conversion register
            dataLow = read(obj.i2cObj, 1, 'uint8');
            % Pack both the bytes into int16 register
            data = typecast(bitor(bitshift(uint16(dataHigh),8), uint16(dataLow)), 'int16');
            % Output the raw ADC data - content of conversion register
            rawData = typecast(data,'uint16');             
            voltage = double(data) * double(obj.VoltageScale) / obj.ADC_SCALAR;
        end
    end
    
    methods
        function set.Address(obj, value)
            if isnumeric(value)
                validateattributes(value, {'numeric'}, ...
                    {'scalar', 'nonnegative'}, '', 'Address');
            else
                validateattributes(value, {'char'}, ...
                    {'nonempty'}, '', 'Address');
                value = obj.hex2dec(value);
            end
            if (value < obj.hex2dec('0x48')) || (value > obj.hex2dec('0x51'))
                error('raspi:ads1015:InvalidI2CAddress', ...
                    'Invalid I2C address. I2C address must be one of the following: 0x48, 0x49, 0x50, 0x51');
            end
            obj.Address = value;
        end
        
        function set.SamplesPerSecond(obj, value)
            validateattributes(value, {'numeric'}, ...
                {'scalar', 'nonnan', 'finite'}, '', 'SamplesPerSecond');
            if ~ismember(value, obj.AvailableSamplesPerSecond)
                error('raspi:ads1015:InvalidSamplesPerSecond', ...
                    'SamplesPerSecond must be one of the following: %s', ...
                    strjoin(string(obj.AvailableSamplesPerSecond)));
            end
            obj.SamplesPerSecond = value;
        end
        
        function set.VoltageScale(obj, value)
            validateattributes(value, {'numeric'}, ...
                {'scalar', 'nonnan', 'finite'}, '', 'VoltageScale');
            if ~ismember(value, obj.AvailableVoltageScale)
                error('raspi:ads1015:InvalidVoltageScale', ...
                    'VoltageScale must be one of the following: %s', ...
                    strjoin(string(obj.AvailableVoltageScale)));
            end
            obj.VoltageScale = value;
            switch obj.VoltageScale
                case 6.144
                    obj.PGAbits = 0; %#ok<*MCSUP>
                case 4.096 
                    obj.PGAbits = 1; 
                case 2.048 
                    obj.PGAbits = 2;
                case 1.024 
                    obj.PGAbits = 3;
                case 0.512 
                    obj.PGAbits = 4;
                case 0.256
                    obj.PGAbits = 5;
                otherwise
                    obj.PGAbits = 0;
            end
        end
        
        function set.OperatingMode(obj, value)
            value = validatestring(value, obj.AvailableOperatingMode,'');
            obj.OperatingMode = value;
        end
    end
    
    methods (Access = protected)
        
        function configReg = getConfigReg(obj, AINp, AINn)
            
            configReg = uint16(0);
            % Disable comparator
            configReg = bitor(configReg, bitshift(uint16(bin2dec('11')), obj.CONFIG_COMP_QUE_SHIFT));
            
            % Set samples per second bits DR[2:0]
            switch obj.SamplesPerSecond
                case 128
                    DRbits = 0;
                case 250
                    DRbits = 1;
                case 490
                    DRbits = 2;
                case 920
                    DRbits = 3;
                case 1600
                    DRbits = 4;
                case 2400
                    DRbits = 5;
                case 3300
                    DRbits = 6;                
                otherwise
                    DRbits = 4; % Assume SPS = 1600
            end
            configReg = bitor(configReg, bitshift(uint16(DRbits), obj.CONFIG_DR_SHIFT));
            
            % Set operating mode bits MODE[8]
            if isequal(obj.OperatingMode, 'single-shot')
                MODEbits = uint16(1);
                configReg = bitor(configReg, bitshift(MODEbits, obj.CONFIG_MODE_SHIFT));
                configReg = bitor(configReg, bitshift(uint16(1), obj.CONFIG_OS_SHIFT));
            end
            
            % Set PGA bits PGA[2:0]
            configReg = bitor(configReg, bitshift(uint16(obj.PGAbits), obj.CONFIG_PGA_SHIFT));
            
            % Set MUX bits MUX[2:0]
            if AINn == -1
                switch AINp
                    case 0
                        MUXbits = bin2dec('100');
                    case 1
                        MUXbits = bin2dec('101');
                    case 2
                        MUXbits = bin2dec('110');
                    case 3
                        MUXbits = bin2dec('111');
                end
            else
                if (AINp == 0) && (AINn == 1)
                    MUXbits = bin2dec('000');
                elseif (AINp == 0) && (AINn == 3)
                    MUXbits = bin2dec('001');
                elseif (AINp == 1) && (AINn == 3)
                    MUXbits = bin2dec('010');
                elseif (AINp == 2) && (AINn == 3)
                    MUXbits = bin2dec('011');
                else
                    error('raspi:ads1015:InvalidAIN', ...
                        ['Invalid (AINp, AINn) pair for differential voltage measurement. ', ...
                        'Supported (AINp, AINn) values are: (0, 1), (0, 3), (1, 3), (2, 3).']);
                end
            end
            configReg = bitor(configReg, bitshift(uint16(MUXbits), obj.CONFIG_MUX_SHIFT));   
        end
    end
    
    methods (Access = private)
        function configureDevice(obj)
            
            bytesOfConfigRegister = typecast(obj.ConfigReg,'uint8');
            % ADS1015 sensor expects the higher byte to be sent first. 
            % So, on little endian machines like Raspberry Pi and intel PCs, 
            % we need to send the second memory location of the
            % bytesOfConfigRegister first and then the first memory
            % location
            write(obj.i2cObj, [obj.CONFIG_REG, bytesOfConfigRegister(2), bytesOfConfigRegister(1)],'uint8');
        end
        
        function reg = readConfigReg(obj)
            reg = swapbytes(readRegister(obj.i2cObj, obj.CONFIG_REG, 'uint16'));
        end
    end
    
    methods (Static, Hidden)
        function decvalue = hex2dec(hexvalue)
            decvalue = hex2dec(regexprep(hexvalue, '0x', ''));
        end
        
        function hexvalue = dec2hex(decvalue)
            hexvalue = sprintf('0x%02s', dec2hex(decvalue));
        end
    end
end