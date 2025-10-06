clear all
close all

T = 30;
rate = 400;

cal0 = -1;
cal1 = -1;
cal2 = -1;
cal3 = -1;

daqreset
d = daq('ni');
dio = addoutput(d, 'Dev2', 'port0/line0:7', 'Digital')
enable = [1 1 1 1 1 1 1 1];
write(d, enable)

daqreset
L = daqlist;
disp(strcat("Using ", L.Description))
d = daq('ni');
ch1 = addinput(d, 'Dev2', 1, 'Voltage'); %Sensor0
d.Rate = rate;
ch1.Range = [-10 10];
set(ch1)

disp('starting')
pause(0.1)
Data= read(d, seconds(T));
sensor0 = Data.Dev2_ai0 * cal0;

figure(1)
plot(Data.Time, sensor0, 'ro')