classdef NEO_M8U 
    %Sparkfun I2C NEO-M8U Module Driver
    % Please DO NOT EDIT THIS CODE
    % Copyright Olin Robot Lab 2021
    %
    
   %{
    % Basic Usage:
    
            % Create Connection to Raspi Device 
    
        mypi = raspi;
    
            % Create Class Instance
    
        neo = NEO_M8U(mypi);
     
            % Get basic data
            % returns a struct with fields: longitude, lattitude, roll, pitch, and heading.
       
        basic_data = neo.getBasic()
    
    
    
    
            % ADVANCED
            % Get all avaliable messages
            % msgs = neo.read().msgs;
    
            % OR get a specific message (only useful for occaisional polling of specific data, polling_freq < 1Hz)
    
            %msg = neo.get(msg_name)
    
            % Currently enabled messages are: 
            % msg_name = 'NAV_PVT', 'NAV_ATT'
           
           
    
        % For additional info about each message's fields, 
        % units of measurments, etc, see:
        % https://cdn.sparkfun.com/assets/c/f/d/8/a/u-blox8-M8_ReceiverDescrProtSpec__UBX-13003221__Public.pdf
   %}
   
    properties (Constant)
        %     this is the default I2C bus, alternate bus 'i2c-0' not typically used
        DEFAULT_I2C_BUS = 'i2c-1';
        %     default hardware address and read/write registers, accessible from output struct
        DEFAULT_HW_ADDRESS = '0x42'; % normally 42(programmable, let me know if needed) 
       
        DEFAULT_NAME = "I2C_NEO_M8U";
        
        ubx = UBX();
    end
    properties
        device;
        data;
    end
    methods
        function obj = NEO_M8U(raspberry_pi) 
            arguments
               raspberry_pi;
            end
              obj.device = i2cdev(raspberry_pi, NEO_M8U.DEFAULT_I2C_BUS, NEO_M8U.DEFAULT_HW_ADDRESS);   
        end
        function response = sendUBX(obj, ubx_msg)
            
            %writeRegister(obj.device, 0xFF,ubx_msg) %point to data register
           
        for i=(1:length(ubx_msg))
               write(obj.device, ubx_msg(i)); 
        end
            
            response = obj.read();
        end
        function frames = split(obj, bulk_read)
           %{
            while isequal(bulk_read,[])
                "retrying..."
                pause(0.1);
                bulk_read = obj.read().bytes;
            end
            %}
            frames = cell(ceil(length(bulk_read)/8),1); %pre-allocate frames
            i=1;
            
            while (bulk_read(1)~=255)
                
            L = typecast(uint8(bulk_read(5:6)),'uint16');
            %length(bulk_read)
            if(L>1000)
                bulk_read(5:6)
            end
            
            frames{i} = bulk_read(1:8+L);
            bulk_read = bulk_read(9+L:end);
            i = i+1;
            
            if length(bulk_read)<=8
                %bulk_read %debug
                frames(i:end) = []; %remove unused cells in frames
                break;
            end
            end
        end
        function data = read(obj,writeCount)
            
             if ~exist('writeCount','var')
                 % third parameter does not exist, so default it to something
                 writeCount = 1;
             end
            
           
          
                data.length = 0;
                data.bytes = [];
                reading = read(obj.device, 8);
                i = 0;
                if isequal(reading, [255 255 255 255 255 255 255 255])
                    pause(0.2);
                    reading = read(obj.device, 8);
                end
                while and(~isequal(reading, [255 255 255 255 255 255 255 255]), data.length < 2^16-1)
                 data.bytes = [data.bytes reading];
                 data.length = length(data.bytes);
                 reading = read(obj.device, 8);
                 i=i+1;
                end
                data.timestamp = datetime('now');          
                 if (data.length==0)
                     pause(1);
                    data = obj.read(writeCount+1);
                 else   
                 data.frames = obj.split(data.bytes);
                 data.msgs = struct();
                 for i=(1:length(data.frames))
                     msg = obj.ubx.decode(data.frames{i});
                     data.msgs.(msg.class_id) =  obj.ubx.parse(msg);
                 end
                end 
        end
        function msg = get(obj, class_id)
           msgs = obj.read().msgs;
           if isfield(msgs, class_id)
           msg = msgs.(class_id);
           else %assume message with that class_id is enabled
               pause(0.1);
           msg = obj.get(class_id);
           end
        end
       function basic = getBasic(obj)
             % basic data:
            try
                msgs = obj.read().msgs;
                basic.longitude = msgs.NAV_PVT.lon;
                basic.lattitude = msgs.NAV_PVT.lat;
                basic.roll = msgs.NAV_ATT.roll;
                basic.pitch = msgs.NAV_ATT.pitch;
                basic.heading = msgs.NAV_ATT.heading;
            catch
                %msg = 'retrying...'
                %clear msg;
                pause(0.1);
                basic = obj.getBasic();
            end 
       end
    end
end


