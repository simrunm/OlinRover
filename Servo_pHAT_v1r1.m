classdef Servo_pHAT_v1r1
    %Sparkfun I2C Pi Servo pHAT Driver 
    % Version 1 Revision 1
    % Copyright Olin Robot Lab 4/28/2021
    %        
    
    %{
    %Basic Usage:
    
            % Create Connection to Raspi Device
    
        mypi = raspi;
    
            % Create Class Instance
    
        Servos = Servo_pHAT_v1r1(mypi);
    
       % Configure Settings - Optional. Defaults match "TIANKONGRC Micro Servo 9g SG90".

        Servos.SERVO_MAX_DUTYCYCLE = 0.10; % 10% = 2ms of the 20ms period
        Servos.SERVO_MIN_DUTYCYCLE = 0.05; %  5% = 1ms of the 20ms period
        Servos.SERVO_OP_ANGLE = 180; % Degrees
        Servos.SERVO_FREQUENCY = 50 %Hz
    
      % TO SET SERVO
      % call Servos.setServoPWM(servo_number,dutycycle) :  0 < dutycycle <= 100
      %   or Servos.setServoAngle(servo_number, angle) : 0 < angle <= Servos.SERVO_OP_ANGLE
      
      % TO READ SERVO
      % call Servos.readServoPWM(servo_number)
            % - returns the dutycycle, 0 < dutycycle <= 100
      %   or Servos.readServoAngle(servo_number, angle)
            % - returns the angular displacement (angle) of the servo,
                % 0 < angle <= Servos.SERVO_OP_ANGLE
    
    
    %}
    
    properties (Constant)
        %     this is the default I2C bus, alternate bus 'i2c-0' not typically used
        DEFAULT_I2C_BUS = 'i2c-1';
        %     default hardware address and read/write registers, accessible from output struct
        DEFAULT_HW_ADDRESS = '0x40'; % (Fixed)
        
        DEFAULT_NAME = "Pi Servo HAT";
        
        %     Default Servo Frequency:
        DEFAULT_SERVO_FREQUENCY = 50;   %Hz == 20ms period
        
        %Frequency of pHAT's internal clock
        HW_CLOCK_FREQ = uint32(25000000); %Hz
        
        %   ***** Start Defaults for "TIANKONGRC Micro Servo 9g SG90".******
        
        %     ***Default Servo Dutycyle Range***
        %          - overrides by setting Servos.SERVO_MAX_DUTYCYCLE and
        %                                 Servos.SERVO_MIN_DUTYCYCLE properties
        DEFAULT_SERVO_MAX_DUTYCYCLE = 0.10; % = 2ms pulse width
        DEFAULT_SERVO_MIN_DUTYCYCLE = 0.05; % = 1ms pulse width
        
        %     ***Default Servo Angle Range***
        %          - overrides by setting Servos.SERVO_OP_ANGLE property
        DEFAULT_SERVO_OP_ANGLE = 190; % Degrees
        
        %   ***** End Defaults for "TIANKONGRC Micro Servo 9g SG90".******
        
        
        %Special Use Addresses:
        gcAddr = '0x00'     % General Call address for software reset
        acAddr = '0x70'     % All Call address- used for modifications to
        % multiple PCA9685 chips reguardless of thier
        % I2C address set by hardware pins (A0 to A5).
        subAddr_1 = '0x71'  % 1110 001X or 0xE2 (7-bit)
        subAddr_2 = '0x72'  % 1110 010X or 0xE4 (7-bit)
        subAddr_3 = '0x74'  % 1110 100X or 0xE8 (7-bit)
    end
    properties
        device
        servoAddr = []
        SERVO_MAX_DUTYCYCLE = Servo_pHAT_v1r1.DEFAULT_SERVO_MAX_DUTYCYCLE
        SERVO_MIN_DUTYCYCLE = Servo_pHAT_v1r1.DEFAULT_SERVO_MIN_DUTYCYCLE
        SERVO_OP_ANGLE = Servo_pHAT_v1r1.DEFAULT_SERVO_OP_ANGLE
        SERVO_FREQUENCY = Servo_pHAT_v1r1.DEFAULT_SERVO_FREQUENCY
    end
    methods
        function obj = Servo_pHAT_v1r1(raspberry_pi)
            arguments
                raspberry_pi;
            end
            obj.device = i2cdev(raspberry_pi, Servo_pHAT_v1r1.DEFAULT_I2C_BUS, Servo_pHAT_v1r1.DEFAULT_HW_ADDRESS);
            
            for i = (1:16)
                obj.servoAddr(i).SERVO_ON_LOW_BYTE = 4*i+2;
                obj.servoAddr(i).SERVO_ON_HIGH_BYTE = 4*i+3;
                obj.servoAddr(i).SERVO_OFF_LOW_BYTE = 4*i+4;
                obj.servoAddr(i).SERVO_OFF_HIGH_BYTE = 4*i+5;
            end
            
            %tell the device to set the correct PWM output frequency, can
            %only writeable while sleep-bit is 1 (device is sleeping)
            
            %tell the device to sleep => sets sleep-bit to 1.
            writeRegister(obj.device,0,0b00010001);
            
            PRE_SCALE = round(Servo_pHAT_v1r1.HW_CLOCK_FREQ/(4096*Servo_pHAT_v1r1.DEFAULT_SERVO_FREQUENCY))-1;
            writeRegister(obj.device, 0xFE, PRE_SCALE);
            
            %tell the device to stop sleeping => sets sleep-bit to 0.
            writeRegister(obj.device,0,0b00000001);
            
        end
        function freq = getServoFrequency(obj)
            write(obj.device,0xFE); %select PRE_SCALE register
            PRE_SCALE = uint32(read(obj.device, 1));
            freq = round(Servo_pHAT_v1r1.HW_CLOCK_FREQ/((PRE_SCALE+1)*4096));
        end
        function new_servo_freq = setServoFrequency (obj,freq)
            
            %tell the device to sleep => sets sleep-bit to 1.
            writeRegister(obj.device,0,0b00010001);
            
            %change the PWM frequency
            PRE_SCALE = round(Servo_pHAT_v1r1.HW_CLOCK_FREQ/(4096*freq))-1;
            writeRegister(obj.device, 0xFE, PRE_SCALE);
            
            %tell the device to stop sleeping => sets sleep-bit to 0.
            writeRegister(obj.device,0,1);
            
            %confirm successful change to PWM frequency by reading and
            %returning the value in the PRE_SCALE register and reversing
            %the calculation
            new_servo_freq = obj.getServoFrequency();
        end
        
        function success = setServoPWM(obj, servo_number, dutycycle)
            % NOTE: 0 < dutycycle <= 100
            
            %on_latency bytes - currently coded for zero latency
            on_high_byte = 0;
            on_low_byte = 0;
            
            %off_latency bytes
            if(dutycycle > 0)
                off_word = dec2bin(uint16((obj.SERVO_MIN_DUTYCYCLE + (obj.SERVO_MAX_DUTYCYCLE-obj.SERVO_MIN_DUTYCYCLE)*(dutycycle/100))*4095));
            else
                off_word = '0';
            end
            for i=(1:16-strlength(off_word))
                off_word = "0" + off_word;
            end
            off_word = char(off_word);
            off_high_byte = uint8(bin2dec(off_word(1:8)));
            off_low_byte = uint8(bin2dec(off_word(9:16)));
            
            % Register writes
            writeRegister(obj.device, obj.servoAddr(servo_number+1).SERVO_ON_HIGH_BYTE,on_high_byte);
            writeRegister(obj.device, obj.servoAddr(servo_number+1).SERVO_ON_LOW_BYTE,on_low_byte);
            writeRegister(obj.device, obj.servoAddr(servo_number+1).SERVO_OFF_HIGH_BYTE,off_high_byte);
            writeRegister(obj.device, obj.servoAddr(servo_number+1).SERVO_OFF_LOW_BYTE,off_low_byte);
            
            % Check to confirm that all bytes were successfully written to
            % the registers
            check.ON_HIGH_BYTE = double(readRegister(obj.device, obj.servoAddr(servo_number+1).SERVO_ON_HIGH_BYTE));
            check.ON_LOW_BYTE = double(readRegister(obj.device, obj.servoAddr(servo_number+1).SERVO_ON_LOW_BYTE));
            check.OFF_HIGH_BYTE = double(readRegister(obj.device, obj.servoAddr(servo_number+1).SERVO_OFF_HIGH_BYTE));
            check.OFF_LOW_BYTE = double(readRegister(obj.device, obj.servoAddr(servo_number+1).SERVO_OFF_LOW_BYTE));
            check.milliseconds.on_latency = (1000/obj.SERVO_FREQUENCY)*(check.ON_HIGH_BYTE*(2^8)+check.ON_LOW_BYTE)/4095; %ms
            check.milliseconds.pulse_duration = (1000/obj.SERVO_FREQUENCY)*(check.OFF_HIGH_BYTE*(2^8)+check.OFF_LOW_BYTE)/4095; %ms
            
            % check.milliseconds for debugging purposes
            
            success = (uint8(check.ON_HIGH_BYTE) == on_high_byte)&&(uint8(check.ON_LOW_BYTE) == on_low_byte)&&(uint8(check.OFF_HIGH_BYTE) == off_high_byte)&&(uint8(check.OFF_LOW_BYTE) == off_low_byte);
        end
        function success = setServoAngle(obj, servo_number, angle)
            % helper function to convert between dutycycle and angle
            success = obj.setServoPWM(servo_number, 100*angle/obj.SERVO_OP_ANGLE);
        end
        function dutycycle = readServoPWM(obj, servo_number)
            OFF_HIGH_BYTE = double(readRegister(obj.device, obj.servoAddr(servo_number+1).SERVO_OFF_HIGH_BYTE));
            OFF_LOW_BYTE = double(readRegister(obj.device, obj.servoAddr(servo_number+1).SERVO_OFF_LOW_BYTE));
            raw_dutycycle = (OFF_HIGH_BYTE*(2^8)+OFF_LOW_BYTE)/4095;
            dutycycle = 100*(raw_dutycycle-obj.SERVO_MIN_DUTYCYCLE)/(obj.SERVO_MAX_DUTYCYCLE-obj.SERVO_MIN_DUTYCYCLE);
        end
        function angle = readServoAngle(obj, servo_number)
            angle = obj.SERVO_OP_ANGLE * (readServoPWM(obj, servo_number)/100.0);
        end
    end
end


