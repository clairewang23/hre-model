using Polynomials
using PyPlot  # Assuming you're using PyPlot based on plt usage

# Define polynomials
# river_rising_poly = Polynomial([-0.26539793623361047, 2.6192340898018793, - 1.6658626892074053])
# river_falling_poly = Polynomial([-0.9234834889073926, 3.4708509183225087, - 1.8033721743372466])
# Updated polynomials after AGW filter implementation:
river_rising_poly = Polynomial([-0.2872034807507623, 2.6666189718695965, - 1.5659931387023205])
river_falling_poly = Polynomial([-0.9889458308254395, 4.015230262207393, - 2.261963393392087])

bay_o1_poly = Polynomial([-0.25997538639394513, 0.09777363681119927])
bay_o2_poly = Polynomial([-0.2739713544577111, 0.14711345756388355, 0.07211584849440995])
# bay_rising_poly = Polynomial([-0.2739713544577111, 0.14711345756388355, 0.07211584849440995])
# bay_falling_poly = Polynomial([0.07266060547979399, 0.5574870296230111, 0.21164958534164496])
# Updated polynomials after AGW filter implementation:
bay_rising_poly = Polynomial([-0.2948249975986983, 0.1799879532921597, 0.0965604066817042])
bay_falling_poly = Polynomial([0.0918498971455922, 0.6351233571549071, 0.24142792052758394])

# Calculate head difference
USGS_Z = USGS_riverH .- USGS_bayH

# Define output vector
Q_ratingcurve = zeros(length(USGS_Z))

# Adjust start and end safely (must ensure indexing doesn't go out of bounds)
# start_ind = 433 # start at 2 to allow Z[ind-1] to exist, GIVE MODELS A COUPLE DAYS TO SPIN UP
start_ind = findfirst(x -> x ==DateTime(2022, 7, 12, 18, 0), USGS_datetime)
# end_ind = 288 * 14 + start_ind          # length = 4896
end_ind = findfirst(x -> x ==DateTime(2022, 7, 15, 0, 0), USGS_datetime)
n_points = end_ind - start_ind + 1

# Constants
# culvert_h = 5 * ft_to_m
culvert_h_bay = 9.75 * ft_to_m # (10'3" - 6")
culvert_h_river = 5.75 * ft_to_m # (6'3" - 6")
# culvert_top_Z = -26.1317 # in camera coords
culvert_top_Z_bay = 1.55143 # in gauge coords
culvert_bot_Z_bay = culvert_top_Z_bay - culvert_h_bay
culvert_bot_Z_river = culvert_bot_Z_bay + (1.5*ft_to_m)
culvert_top_Z_river = culvert_bot_Z_river + culvert_h_river
culvert_top_Z_inner = culvert_bot_Z_river + 5 * ft_to_m
river_culvert_width = 6*ft_to_m + (7/12)*ft_to_m + 7*ft_to_m + (2/12)*ft_to_m + 6*ft_to_m
bay_culvert_width = 6*ft_to_m #+ (7/12)*ft_to_m
vel_idx = 0.9

# Main loop
window_halfwidth = 6  # ~30 minutes

for (local_ind, Z) in enumerate(USGS_Z[start_ind:end_ind])
    global_ind = start_ind + local_ind - 1

    # Local window to evaluate rise/fall trend
    window_start = max(global_ind - window_halfwidth, 1)
    window_end   = min(global_ind + window_halfwidth, length(USGS_Z))
    Z_window = USGS_Z[window_start:window_end]

    if Z == 0
        flowrate = 0.0

    elseif Z > 0  # River side
        h = USGS_riverH[global_ind] - culvert_bot_Z_river
        A_river = h * river_culvert_width

        # Determine whether rising or falling
        is_local_max = global_ind == window_start - 1 + findmax(Z_window)[2]
        Usurf = is_local_max || global_ind > window_start - 1 + findmax(Z_window)[2] ?
                river_falling_poly(Z) : river_rising_poly(Z)

        flowrate = Usurf < 0 ? 0 : Usurf * A_river

    # else  # Z < 0 → Bay side
    #     if USGS_bayH[global_ind] >= culvert_top_Z_bay
    #         h = culvert_h_bay
    #     else
    #         h = USGS_bayH[global_ind] - culvert_bot_Z_bay
    #     end
    #     A_bay = h * bay_culvert_width

    #     is_local_min = global_ind == window_start - 1 + findmin(Z_window)[2]
    #     Usurf = is_local_min || global_ind > window_start - 1 + findmin(Z_window)[2] ?
    #             bay_falling_poly(Z) : bay_rising_poly(Z)

    #     flowrate = Usurf * A_bay
    #     if flowrate > 0
    #         flowrate = 0
    #     end
    # end
    else  # Z < 0 → Bay side
        if USGS_bayH[global_ind] >= culvert_top_Z_bay
            h = culvert_h_bay
            A_bay = h * bay_culvert_width
            Usurf = bay_rising_poly(Z)  # immediately switch to falling
        else
            h = USGS_bayH[global_ind] - culvert_bot_Z_bay
            A_bay = h * bay_culvert_width

            is_local_min = global_ind == window_start - 1 + findmin(Z_window)[2]
            Usurf = is_local_min || global_ind > window_start - 1 + findmin(Z_window)[2] ?
                    bay_falling_poly(Z) : bay_rising_poly(Z)
        end

        flowrate = Usurf * A_bay
        if flowrate > 0
            flowrate = 0
        end
    end
    Q_ratingcurve[global_ind] = flowrate * vel_idx
end


start_time = USGS_datetime[start_ind]
end_time = USGS_datetime[end_ind]

mh_start_ind = findmin(abs.(mh_filt.Datetime .- start_time))[2]
mh_end_ind   = findmin(abs.(mh_filt.Datetime .- end_time))[2]

kb_start_ind = findmin(abs.(kb_filt.date_time .- start_time))[2]
kb_end_ind   = findmin(abs.(kb_filt.date_time .- end_time))[2]

tick_interval = Dates.Hour(24) # Dates.Hour(3)
tick_positions = start_time:tick_interval:end_time
tick_labels = Dates.format.(tick_positions, "dd-HH:MM")

# Plotting
plt.figure()
plt.axhline(0, color="black", label="_nolegend_")
plt.plot(mh_filt.Datetime[mh_start_ind:mh_end_ind], mh_filt."Total_Discharge_m3/s"[mh_start_ind:mh_end_ind], c=:"#f781bf", linewidth = 2, linestyle="--")
plt.plot(kb_filt.date_time[kb_start_ind:kb_end_ind], kb_filt.Qtotal_m3s[kb_start_ind:kb_end_ind], 
    c=:"#4daf4a", linewidth = 2, linestyle="--")
plt.plot(USGS_datetime[start_ind:end_ind], Q_ratingcurve[start_ind:end_ind])
plt.legend(["Model: depth-averaged Delft3D","Model: hydraulic mass balance","IR-QIV: rating curve hydrograph"], 
    loc = "lower left")#  )
plt.ylabel("Discharge (m^3/s)")
plt.xticks(tick_positions, tick_labels)#, rotation = 45)  # Set x-axis tick positions and labels
plt.xlabel("Day-hour:minute (July 2022)")
plt.ylim([-40, 40])
# plt.axvline.(USGS_datetime[cross_inds])
plt.gcf()