%{
daq_height_velocity.m

Collect Banner sensor and ADV data for one trial
Write data to csv
%}

close all
clear

% DATA COLLECTION
dq = daq("ni");

% add inputs

