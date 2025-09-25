%{
daq_height_velocity.m

Collect Banner sensor data for one trial
Write data to csv
%}

close all
clear

% turn on ProCoDA Box
daqreset
dq = daq("ni");
dio = addoutput(dq, 'Dev1', 'post0/line0:7', 'Digital')
enable = [1 1 1 1 1 1 1 1];
write(dq, enable)

% add inputs
ch0 = addinput(dq, "Dev1", "ai0", "Voltage"); % head tank sensor
ch0.TerminalConfig = "SingleEnded";

ch1 = addinput(dq, "Dev1", "ai1", "Voltage"); % supercritical sensor
ch1.TerminalConfig = "SingleEnded";

ch2 = addinput(dq, "Dev1", "ai2", "Voltage"); % subcritical sensor
ch2.TerminalConfig = "SingleEnded";

% collect data
dt_sensor = 0.03; % Sensor sampling rate.
fs = 1/dt_sensor; % daq sampling rate (Hz)
dt = 60; % trial length (s)
dq.Rate = fs;
[data, time, start] = read(dq, seconds(dt), OutputFormat="Matrix");
V_ai0 = data(:,1);
V_ai1 = data(:,2);
V_ai2 = data(:,3);

% plot data
figure()
subplot(311)
plot(time, V_ai0)
xlabel('Time (s)')
ylabel('Voltage (V)')

subplot(312)
plot(time, V_ai1)
xlabel('Time (s)')
ylabel('Voltage (V)')

subplot(313)
plot(time, V_ai2)
xlabel('Time (s)')
ylabel('Voltage (V)')

% write to spreadsheet
tab = table(time, V_ai0, V_ai1, V_ai2);
date = string(datetime('now', 'Format', 'yyyy-MM-dd''_''HH-mm-ss'));
path = "sensor_data\exp1\";
filename = date + "_" + "sensor_data" + ".csv";
writetable(tab, fullfile(path,filename));