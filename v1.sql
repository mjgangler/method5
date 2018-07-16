select
            '<tr><td>'||
            tablespace||'</td><td>'||
            hosts||'</td><td>'||
            current_percent_used ||'%</td><td>'||
            forecast_2 ||'%</td><td>'||
            forecast_7 ||'%</td><td>'||
            forecast_30 ||'%</td><td>'||
            trim(to_char(round(last_total_mb/1024),'999,999'))||'</td><td>'||
            trim(to_char(round(last_used_mb/1024),'999,999'))||'</td><td>'||
            trim(to_char(round(last_"free_mb"/1024),'999,999'))||'</td><td>'||
            '<img alt="'||tablespace||' chart" src="'||chart||'">'||'</td></tr>'||
            chr(10) html
            ,user_friendly_values.*
        from
        (
            --User-friendly values, sort for top N reporting.
            select distinct tablespace, hosts, round(used) current_percent_used
                ,round(forecast_2 / used_mb * 100) forecast_2
                ,round(forecast_7 / used_mb * 100) forecast_7
                ,round(forecast_30 / used_mb * 100) forecast_30
                ,last_total_mb, last_used_mb, last_"free_mb"
                ,chart
            from
            (
                --Chart.
                select
                    --Create a Google chart.
                    --See here for documentation: https://developers.google.com/chart/image/docs/gallery/line_charts
                    replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
                        'https://chart.googleapis.com/chart?' ||                        --Base URL.
                        'chxt=x,y$AMP$chxl=0:|-30|-15|0|15|30|1:|0|$GREATEST_VALUE$' || --X and Y axis labels.
                        '$AMP$cht=lxy$AMP$chs=1000x300$AMP$chd=t:$X$|$Y$' ||            --X and Y data for the past 30 days.
                        '|0,100|$AVAILABLE_SPACE$,$AVAILABLE_SPACE$' ||                 --Available space line.
                        '|$FCST2_X1$,$FCST2_X2$|$FCST2_Y1$,$FCST2_Y2$' ||               --Forecast 2 line.
                        '|$FCST7_X1$,$FCST7_X2$|$FCST7_Y1$,$FCST7_Y2$' ||               --Forecast 7 line.
                        '|$FCST30_X1$,$FCST30_X2$|$FCST30_Y1$,$FCST30_Y2$' ||           --Forecast 30 line.
                        '$AMP$chco=000000,FF0000,00FF00,0000FF,FFC0CB'||                --Chart colors.  Black for real values, red for max available, then green, blue, pink for forecasts.
                        '$AMP$chls=5,5,0|1,1,0|4,4,4|4,4,4|4,4,4'||                     --Line style.  Solid for real values, solid for max available used, dashed for forecasts.
                        '$AMP$chdl=Past|Available|2-day|7-day|30-day'||                 --Chart labels.
                        '$AMP$chtt=$DISKGROUP$+Growth+and+Forecasts'                    --Chart title.
                        --
                        --REPLACE:
                        --
                        --Some IDEs will interpret the ampersand as a variable.
                        , '$AMP$', chr(38))
                        --Display in TB if large, or GB if small
                        , '$GREATEST_VALUE$', case when greatest_value_mb > 1024*1024 then round(greatest_value_mb/1024/1024, 1) || '+T' else round(greatest_value_mb/1024) || '+G' end)
                        , '$X$', x)
                        , '$Y$', y)
                        , '$AVAILABLE_SPACE$', round(last_total_mb/greatest_value_mb*100, 1))
                        , '$FCST2_X1$', round(FCST2_X1, 1))
                        , '$FCST2_X2$', round(adjusted_FCST2_X2, 1))
                        --Use NVL(..., -1) because negative values do not appear, but missing values break the chart.
                        , '$FCST2_Y1$', nvl(round(FCST2_Y1, 1), -1))
                        , '$FCST2_Y2$', nvl(round(adjusted_FCST2_Y2, 1), -1))
                        , '$FCST7_X1$', round(FCST7_X1, 1))
                        , '$FCST7_X2$', round(adjusted_FCST7_X2, 1))
                        , '$FCST7_Y1$', nvl(round(FCST7_Y1, 1), -1))
                        , '$FCST7_Y2$', nvl(round(adjusted_FCST7_Y2, 1), -1))
                        , '$FCST30_X1$', round(FCST30_X1, 1))
                        , '$FCST30_X2$', round(adjusted_FCST30_X2, 1))
                        , '$FCST30_Y1$', nvl(round(FCST30_Y1, 1), -1))
                        , '$FCST30_Y2$', nvl(round(adjusted_FCST30_Y2, 1), -1))
                        , '$DISKGROUP$', "Tablespace")  chart
                        ,chart_axes.*
                from
                (
                    --Chart axes.
                    select
                        adjusted_coordinates.*,
                        --X-axis.  Convert the 1-30 to 1-50 to fill up 50% of the chart.
                        listagg(round((30 - date_number_desc + 1) * 5/3, 1), ',') within group (order by date_number_desc desc) over (partition by "Tablespace", hosts) x,
                        --Y-axis.  Percent of the greatest value.
                        listagg(round(used_mb/greatest_value_mb*100), ',') within group (order by date_number_desc desc) over (partition by "Tablespace", hosts) y
                    from
                    (
                        --Adjust final X coordinates.
                        --If the Y goes negative the X will not be 100, but depends on where the line intercepts.
                        --y = mx+b, where y=0, so x = (0-b)/m
                        select chart_slopes_and_intercepts.*
                            ,case when fcst2_y2 < 0 then (0 - intercept2)/slope2 else fcst2_x2 end adjusted_fcst2_x2
                            ,case when fcst7_y2 < 0 then (0 - intercept7)/slope7 else fcst7_x2 end adjusted_fcst7_x2
                            ,case when fcst30_y2 < 0 then (0 - intercept30)/slope30 else fcst30_x2 end adjusted_fcst30_x2
                            ,case when fcst2_y2 < 0 then 0 else fcst2_y2 end adjusted_fcst2_y2
                            ,case when fcst7_y2 < 0 then 0 else fcst7_y2 end adjusted_fcst7_y2
                            ,case when fcst30_y2 < 0 then 0 else fcst30_y2 end adjusted_fcst30_y2
                        from
                        (
                            --Chart with slopes and intercepts.
                            select chart_coordinates.*
                                ,(fcst2_y2 - fcst2_y1)/(fcst2_x2 - fcst2_x1) slope2
                                ,(fcst7_y2 - fcst7_y1)/(fcst7_x2 - fcst7_x1) slope7
                                ,(fcst30_y2 - fcst30_y1)/(fcst30_x2 - fcst30_x1) slope30
                                --y = mx + b, so b = y - mx
                                ,fcst2_y1 - ((fcst2_y2 - fcst2_y1)/(fcst2_x2 - fcst2_x1)) * fcst2_x1 intercept2
                                ,fcst7_y1 - ((fcst7_y2 - fcst7_y1)/(fcst7_x2 - fcst7_x1)) * fcst7_x1 intercept7
                                ,fcst30_y1 - ((fcst30_y2 - fcst30_y1)/(fcst30_x2 - fcst30_x1)) * fcst30_x1 intercept30
                            from
                            (
                                --Chart data with forecast coordinates.
                                select chart_data.*
                                    --Forecast 2 coordinates:
                                    ,29 * 5 / 3 fcst2_x1
                                    ,used_2/greatest_value_mb*100 fcst2_y1
                                    ,100  fcst2_x2
                                    ,forecast_2/greatest_value_mb*100 fcst2_y2
                                    --Forecast 7 coordinates:
                                    ,24 * 5 / 3 fcst7_x1
                                    ,used_7/greatest_value_mb*100 fcst7_y1
                                    ,100  fcst7_x2
                                    ,forecast_7/greatest_value_mb*100 fcst7_y2
                                    --Forecast 30 coordinates:
                                    --There may not be 30 days of data, use the last available X coordinate.
                                    ,round((31 - max(date_number_desc) over (partition by "Tablespace", hosts)) * 5/3, 1) fcst30_x1
                                    ,first_used_mb/greatest_value_mb*100 fcst30_y1
                                    ,100  fcst30_x2
                                    ,forecast_30/greatest_value_mb*100 fcst30_y2
                                from
                                (
                                    --Chart data
                                    select
                                        forecasts.*,
                                        --Largest possible value, others will be compared to it for the y-axis.
                                        greatest(nvl(last_total_mb, 0), nvl(last_used_mb, 0), nvl(forecast_2, 0), nvl(forecast_7, 0), nvl(forecast_30, 0)) greatest_value_mb,
                                        max(case when date_number_desc = 2 then used_mb else null end) over (partition by "Tablespace", hosts) used_2,
                                        max(case when date_number_desc = 7 then used_mb else null end) over (partition by "Tablespace", hosts) used_7
                                    from
                                    (
                                        --Forecast size for next month, based on ordinary least squares regression.
                                        select "Tablespace", hosts, the_date, total_mb, used_mb, ""free_mb"", date_number_asc, date_number_desc
                                            ,last_value(total_mb) over (partition by "Tablespace", hosts order by date_number_asc rows between unbounded preceding and unbounded following) last_total_mb
                                            ,first_value(used_mb) over (partition by "Tablespace", hosts order by date_number_asc rows between unbounded preceding and unbounded following) first_used_mb
                                            ,last_value(used_mb) over (partition by "Tablespace", hosts order by date_number_asc rows between unbounded preceding and unbounded following) last_used_mb
                                            ,last_value("free_mb") over (partition by "Tablespace", hosts order by date_number_asc rows between unbounded preceding and unbounded following) last_free_mb
                                            ,last_value(used_mb) over (partition by "Tablespace", hosts order by date_number_asc rows between unbounded preceding and unbounded following) /
                                             last_value(total_mb) over (partition by "Tablespace", hosts order by date_number_asc rows between unbounded preceding and unbounded following) * 100 last_percent_used
                                            ,count(*) over (partition by "Tablespace") number_of_days
                                            --y = mx + b
                                            ,regr_slope(used_mb, case when date_number_desc <= 2 then date_number_asc else null end) over (partition by "Tablespace", hosts)
                                                * (max(date_number_asc) over (partition by "Tablespace", hosts) + 30)
                                             + regr_intercept(used_mb, case when date_number_desc <= 2 then date_number_asc else null end) over (partition by "Tablespace", hosts)
                                            forecast_2
                                            ,regr_slope(used_mb, case when date_number_desc <= 7 then date_number_asc else null end) over (partition by "Tablespace", hosts)
                                                * (max(date_number_asc) over (partition by "Tablespace", hosts) + 30)
                                             + regr_intercept(used_mb, case when date_number_desc <= 7 then date_number_asc else null end) over (partition by "Tablespace", hosts)
                                            forecast_7
                                            ,regr_slope(used_mb, case when date_number_desc <= 30 then date_number_asc else null end) over (partition by "Tablespace", hosts)
                                                * (max(date_number_asc) over (partition by "Tablespace", hosts) + 30)
                                             + regr_intercept(used_mb, case when date_number_desc <= 30 then date_number_asc else null end) over (partition by "Tablespace", hosts)
                                            forecast_30
                                        from
                                        (
                                            --Convert dates to numbers
                                            select "Tablespace", hosts, the_date, total_mb, used_mb, "free_mb"
                                                ,the_date - min(the_date) over () + 1 date_number_asc
                                                ,max(the_date) over () - the_date + 1 date_number_desc
                                            from
                                            (
                                                --Historical "Tablespace" sizes.
                                                select "Talespace", the_date, total_mb, total_mb - "free_mb" used_mb, free_mb
                                                from nonasm_diskgroup_fcst
                                                join
                                                (
                                                    --Databases and hosts.
                                                    select
                                                        lower(database_name) database_name,
                                                        --Remove anything after a "." to keep the display name short.
                                                        listagg(regexp_replace(host_name, '\..*'), chr(10)) within group (order by host_name) hosts
                                                    from m5_database
                                                    group by lower(database_name)
                                                ) databases
                                                    on nonasm_diskgroup_fcst.database_name = databases.database_name
                                                where "allocated_mb" <> 0
                                                    and the_date > sysdate - 30
                                                    --Exclude some "Tablespace"s that constantly grow and shrink.
                                                    and "Tablespace" not like '%TEMP%'
                                                    and "Tablespace" not like '%FRADG%'
                                                order by "Tablespace", hosts, the_date
                                            ) historical_data
                                        ) convert_dates_to_numbers
                                        order by "Tablespace", hosts, the_date desc
                                    ) forecasts
                                ) chart_data
                            ) chart_coordinates
                        ) chart_slopes_and_intercepts
                    ) adjusted_coordinates
                ) chart_axes
                --Only display "Tablespace"s with 14 or more days of data.
                where number_of_days >= 14
            ) chart
            order by greatest(forecast_2, forecast_7, forecast_30) desc nulls last
        ) user_friendly_values
        --Top N.
        where rownum <= 10
