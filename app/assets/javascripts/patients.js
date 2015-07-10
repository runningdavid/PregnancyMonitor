function sliderChart() {

    //Data storage
    var chart = {},
        data = {},
        backup = {},
        ranges = [],
        sampled = {},
        options = {},
        ajaxQueue = [],
        THRESHOLD = 5000, //ms
        //categories = [],

        margin = {
            top: 20,
            right: 200,
            bottom: 60,
            left: 50
        },

        margin2 = {
            top: 430,
            right: 10,
            bottom: 20,
            left: 40
        },

        width = 960 - margin.left - margin.right,
        height = (500 - margin.top - margin.bottom) / 3,
        height2 = 500 - margin2.top - margin2.bottom;

    //Define scaling functions
    var parseDate = d3.time.format("%Y-%m-%dT%H:%M:%S.%LZ%Z").parse,

        bisectDate = d3.bisector(function(d) {
            return d.date;
        }).left;

    var xScale = d3.time.scale()
        .range([0, width]),

        xScale2 = d3.time.scale()
        .range([0, width]), // Duplicate xScale for brushing ref later

        yScale = d3.scale.linear()
        .range([height, 0]);

    // Define 40 Custom DDV colors 
    var color = d3.scale.ordinal().range(["#E3CF6D", "#48A36D", "#56AE7C",
        "#64B98C", "#72C39B", "#80CEAA", "#80CCB3", "#7FC9BD",
        "#7FC7C6",
        "#7EC4CF", "#7FBBCF", "#7FB1CF", "#80A8CE", "#809ECE",
        "#8897CE",
        "#8F90CD", "#9788CD", "#9E81CC", "#AA81C5", "#B681BE",
        "#C280B7",
        "#CE80B0", "#D3779F", "#D76D8F", "#DC647E", "#E05A6D",
        "#E16167",
        "#E26962", "#E2705C", "#E37756", "#E38457", "#E39158",
        "#E29D58",
        "#E2AA59", "#E0B15B", "#DFB95C", "#DDC05E", "#DBC75F",
        "#EAD67C",
        "#F2DE8A"
    ]);

    //Define x & y axis
    var xAxis = d3.svg.axis()
        .scale(xScale)
        .orient("bottom")
        //.tickSize(5)
        .tickFormat(d3.time.format("%I:%M:%S %p")), //show more detailed datetime

        xAxis2 = d3.svg.axis() // xAxis for brush slider
        .scale(xScale2)
        .orient("bottom")
        //.tickSize(10)
        .tickFormat(d3.time.format("%I:%M:%S %p")), //show more detailed datetime

        yAxis = d3.svg.axis()
        .scale(yScale)
        .orient("left");

    //Define line
    var line = d3.svg.line()
        .interpolate("linear")
        .x(function(d) {
            return xScale(d.date);
        })
        .y(function(d) {
            return yScale(d.value);
        })
        .defined(function(d) {
            return d.value;
        }); // Hiding line value defaults of 0 for missing data

    var maxY; // Defined later to update yAxis

    var svg,

        //for slider part-----------------------------------------------------------------------------------
        context;

    var brush = d3.svg.brush(); //for slider bar at the bottom

    var contextArea = d3.svg.area() // Set attributes for area chart in brushing context graph
        .interpolate("monotone")
        .x(function(d) {
            return xScale2(d.date);
        }) // x is scaled to xScale2
        .y0(height2) // Bottom line begins at height2 (area chart not inverted) 
        .y1(0); // Top line of area, 0 (area chart not inverted)

    //end slider part----------------------------------------------------------------------------------- 

    //Hover lines
    var hoverLineGroup,
        hoverLine,
        hoverDate;

    //d3 selection variables referred later
    var issue,
        focus,
        columnNames,
        legendSpace;

    //class methods
    chart.setData = function(dataset, transform) {
        //data = dataset;
        ranges = [];

        if(transform) { //transform range-based data to data points
            transformData(dataset);
        }
        processData();

        return chart;
    }

    chart.render = function() {
            columnNames = d3.keys(data); //grab the key values from your first data row
                //these are the same as your column names
                //.slice(1); //remove the first column name (`date`);

            initializeSvg();
            initializeHoverLine();
            drawSlider();
            drawAxes();
            drawLines();
            drawLegend();
            initializeTracker();

            // If data is empty, we want to warn the user
            /*if(data.length == {}) {
                svg.append("text")
                    .attr("class", "warning")
                    .attr("x", width / 3)
                    .attr("y", height / 3)
                    .text("No data is currently available")
                    .attr("font-family", "sans-serif")
                    .attr("font-size", "20px")
                    .attr("fill", "grey");
            }*/

            return chart;
        } // End Data callback function

    chart.update = function() {

        backup = {};

        if(data.length !== 0) {
            columnNames = d3.keys(data);
            svg.data(columnNames);
            //clear brush
            brush.clear();

            //update axes
            svg.select(".x.axis")
                .transition()
                .call(xAxis);

            // may want to update y axis
            /*svg.select(".y.axis")
                .transition()
                .call(yAxis);*/

            //reset brush
            brush.x(xScale2)
                .on("brush", brushed);

            context.select(".x.axis1")
                .transition()
                .call(xAxis2);

            d3.selectAll(".range_indicator").remove();

            //reset brush indicator
            drawBrushIndicator();

            //reset brush area
            context.select(".area").remove();
            //plot the rect as the bar at the bottom
            /*context.append("path") // Path is created using svg.area details
                .attr("class", "area")
                .attr("d", contextArea(categories[0].values)) // pass first categories data .values to area path generator 
                .style("fill", "#f1f1f2")
                .style("opacity", 0.6);*/

            context.append("path") // Path is created using svg.area details
                .attr("class", "area")
                .attr("d", contextArea(data[Object.keys(data)[0]] !== undefined ?
                    data[Object.keys(data)[0]] :
                    0)) // pass first categories data .values to area path generator 
                .style("fill", "#f1f1f2")
                .style("opacity", 0.6);

            context.select(".x.brush").remove();

            context.append("g")
                .attr("class", "x brush")
                .call(brush)
                .selectAll("rect")
                .attr("height", height2) // Make brush rects same height 
                .attr("fill", "#5ae15a")
                .style("opacity", 0.6);

            //clear possible warning message
            issue.selectAll(".warning").remove();

            d3.selectAll(".legend-box")
                .attr("selected", false)
                .attr("fill", "#F1F1F2");

            for(var name in data) {
                d3.select("#button-" + name.replace(" ", "").replace("/", "") + "-value")
                    .attr("fill", color(name))
                    .attr("selected", true);
            }

            options = {};
            //update lines
            d3.selectAll(".circles").remove();
            issue.data(function(k) {
                    options[k] = "value";
                    return [{
                        name: k,
                        sampled: sampled[k],
                        values: data[k]
                    }];
                })
                .select("path") // Redraw lines based on brush xAxis scale and domain
                .transition()
                .attr("d", function(d) {
                    var max = findMaxY(d.values);
                    yScale.domain([0, max]);
                    return line(d.values);
                });
            drawDots();
        }

        return chart;

    }

    function transformData(dataset) {
        //convert both dates to milliseconds
        //data need to have the same sample rate -- edit: no need anymore
        //downsampled = data[0]["downsampled"];

        var dat = {};

        for (i = 0; i < dataset.length; i++) {
            var d = dataset[i];

            var start_date = parseDate(d.range["start"] + "+0000"), //force dates to be UTC since it is stored in database as UTC
                end_date = parseDate(d.range["end"] + "+0000"),
                start_ms = start_date.getTime(),
                end_ms = end_date.getTime();

            if(start_ms !== end_ms) {
                ranges.push({
                    start: start_date,
                    end: end_date
                });
            }

            for(var k in d["data"]) {
                sampled[k] = d["sampled"];

                if (d["option"] !== undefined) {
                    options[k] = d["option"];
                } else {
                    options[k] = "value";
                }

                var datum = d["data"][k];

                if(start_ms === end_ms) {
                    if(typeof dat[k] === "undefined") {
                        dat[k] = [];
                    }
                    dat[k].push({
                        date: start_date,
                        value: JSON.parse(datum)[0]
                    });
                    continue;
                }

                var obj_arr = [];

                if(datum !== null) {
                    datum = JSON.parse(datum);

                    var count = 0;
                    var interval = (end_ms - start_ms) / datum.length;
                    for(j = start_ms; j < end_ms; j += interval) {
                        if(d.option !== undefined && d.option === "min-max") {
                            var values = datum[count];
                            if(values === undefined) {
                                values = datum[count - 1];
                            }
                            var obj1 = {
                                date: new Date(j),
                                value: values[0]
                            };
                            var obj2 = {
                                date: new Date(j),
                                value: values[1]
                            };
                            if(dat[k] === undefined) {
                                dat[k] = [];
                            }
                            dat[k].push(obj1);
                            dat[k].push(obj2);
                            count++;
                            continue;
                        }

                        var obj = {
                            date: new Date(j),
                            value: datum[count]
                        };

                        if(dat[k] === undefined) {
                            dat[k] = [];
                        }
                        
                        if(datum[count] === undefined) {
                            obj["value"] = datum[count - 1];
                        }

                        dat[k].push(obj);
                        count++;
                    }

                    for (var n = i + 1; n < dataset.length; n++) {
                        if (k === Object.keys(dataset[i+1]["data"])[0]) {
                            if (end_ms !== parseDate(dataset[i+1]["range"]["start"] + "+0000").getTime()) {
                                dat[k].push({
                                    date: new Date(j)
                                });
                                break;
                            }
                        }
                    }

                    //BUG!!!
                    //if (d["option"] === undefined || d["option"] === "value") {
                    //dat[k].push({
                    //    date: new Date(i)
                    //});
                    //}
                }

            };

        }
        for(var k in dat) {
            data[k] = dat[k];
        }
        console.log(data);
        console.log("options");
    }

    function processData() {
        color.domain(d3.keys(data).filter(function(key) { // Set the domain of the color ordinal scale to be all the csv headers except "date", matching a color to an issue
            return key !== "date";
        }));

        // TODO:: need to determine the largest range
        xScale.domain(d3.extent(data[Object.keys(data)[0]], function(d) {
            return d.date;
        })); // extent = highest and lowest points, domain is data, range is bouding box

        xScale2.domain(xScale.domain()); // Setting a duplicate xdomain for brushing reference later

    }

    function initializeSvg() {
        //create multiple svgs
        svg = d3.select("#ekg")
            .append("g")
            .selectAll("svg")
            .data(columnNames)
            .enter()
            .append("svg")
            .attr("id", function(d) {
                return "svg-" + d.replace(" ", "").replace("/", "");
            })
            .attr("width", width + margin.left + margin.right)
            .attr("height", function(d) {
                return d === columnNames[columnNames.length - 1] ?
                    height +
                    margin.top + margin.bottom + 30 : height + margin.top +
                    5;
            }) //height + margin.top + margin.bottom
            .append("g")
            .attr("transform", "translate(" + margin.left + "," +
                margin.top +
                ")");

        // Create invisible rect for mouse tracking
        svg.append("rect")
            .attr("width", width)
            .attr("height", height)
            .attr("x", 0)
            .attr("y", 0)
            .attr("class", "mouse-tracker")
            .style("fill", "white");

        //append clip path for lines plotted, hiding those part out of bounds
        svg.append("defs")
            .append("clipPath")
            .attr("id", "clip")
            .append("rect")
            .attr("width", width)
            .attr("height", height);
    }

    //replace data in the data[] array
    // BUG FIX!!
    function updateData(dataset, name) {

        /*dataset[0][name] = dataset[0][name].substring(1, dataset[0][name].length - 1);
        dataset[0][name] = dataset[0][name].split(",");

        console.log("data_length: " + data.length);
        console.log("new_data_length: " + dataset[0][name].length);

        var diff_factor = (data.length - 1) / dataset[0][name].length; //server need to send this later
        console.log("diff_factor: " + diff_factor);

        for (i = 0; i < dataset[0][name].length; ++i) {
            data[i * 2][name] = dataset[0][name][i];
            data[i * 2 + 1][name] = dataset[0][name][i];
        }*/
        var dat = {};

        dataset.forEach(function(d) {
            var start_date = parseDate(d.range["start"] + "+0000"), //force dates to be UTC since it is stored in database as UTC
                end_date = parseDate(d.range["end"] + "+0000"),
                start_ms = start_date.getTime(),
                end_ms = end_date.getTime();

            for(var k in d["data"]) {
                var datum = d["data"][k];
                var obj_arr = [];

                if(datum !== null) {
                    datum = JSON.parse(datum);

                    var count = 0;
                    var interval = (end_ms - start_ms) / datum.length;
                    for(i = start_ms; i <= end_ms; i += interval) {
                        if(d.option === "min-max") {
                            var values = datum[count];
                            if(values === undefined) {
                                values = datum[count - 1];
                            }
                            var obj1 = {
                                date: new Date(i),
                                value: values[0]
                            };
                            var obj2 = {
                                date: new Date(i),
                                value: values[1]
                            };
                            if(dat[k] === undefined) {
                                dat[k] = [];
                            }
                            dat[k].push(obj1);
                            dat[k].push(obj2);
                            count++;
                            continue;
                        }
                        //else
                        var obj = {
                            date: new Date(i),
                            value: datum[count]
                        };

                        if(datum[count] === undefined) {
                            obj["value"] = datum[count - 1];
                        }
                        if(dat[k] === undefined) {
                            dat[k] = [];
                        }
                        dat[k].push(obj);
                        count++;
                    }

                    //make a line
                    dat[k].push({
                        date: new Date(i)
                    });
                    //if (dat[k] === undefined) {
                    //    dat[k] = [];
                    //}
                    //dat[k].push(obj_arr);
                    options[k] = d.option;
                }

            };

        });

        if(backup[name] === undefined) {
            backup[name] = data[name];
        }
        data[name] = dat[name];
        //console.log("updated");
        console.log(data);
        console.log(options);
        //console.log(name);

        d3.select("#line-" + name.replace(" ", "").replace("/", ""))
            .transition()
            .attr("d", function() {
                //console.log(data[name]);
                var max = findMaxY(backup[name]);
                yScale.domain([0, max]);
                return line(data[name]); //d.visible ? line(d.values) : null; // If d.visible is true then draw line for this d selection
            });

    }

    function initializeHoverLine() {
        hoverLineGroup = svg.append("g")
            .attr("class", "hover-line-group");

        hoverLine = hoverLineGroup // Create line with basic attributes
            .append("line")
            .attr("class", "hover-line")
            .attr("x1", 10).attr("x2", 10)
            .attr("y1", 0).attr("y2", height + 10)
            .style("pointer-events", "none") // Stop line interferring with cursor
            .style("opacity", 1e-6); // Set opacity to zero 

        hoverDate = hoverLineGroup
            .append('text')
            .attr("class", "hover-text")
            .attr("y", 10) // hover date text position
            .attr("x", width - 150) // hover date text position
            .style("fill", "black");
    }

    function drawSlider() {
        //for slider part-----------------------------------------------------------------------------------
        context = d3.select("#svg-" + columnNames[columnNames.length -
                1].replace(
                " ", "").replace("/", "")) // Brushing context box container
            .append("g")
            .attr("transform", "translate(" + 50 + "," + (height + 40) +
                ")")
            .attr("class", "context");

        brush.x(xScale2)
            .on("brush", brushed);

        context.append("g") // Create brushing xAxis
            .attr("class", "x axis1")
            .attr("transform", "translate(0," + height2 + ")")
            .call(xAxis2);

        //draw brush indicator
        drawBrushIndicator();

        //plot the rect as the bar at the bottom
        context.append("path") // Path is created using svg.area details
            .attr("class", "area")
            .attr("d", contextArea(data[Object.keys(data)[0]] !== undefined ?
                data[Object.keys(data)[0]] :
                0)) // pass first categories data .values to area path generator 
            .style("fill", "#f1f1f2")
            .style("opacity", 0.6);

        //append the brush for the selection of subsection  
        context.append("g")
            .attr("class", "x brush")
            .call(brush)
            .selectAll("rect")
            .attr("height", height2) // Make brush rects same height 
            .attr("fill", "#5ae15a")
            .style("opacity", 0.6);
        //end slider part-----------------------------------------------------------------------------------
    }

    function drawAxes() {
        //draw x axis
        d3.select("#svg-" + columnNames[columnNames.length - 1].replace(
                    " ", "")
                .replace("/", "")) // Brushing context box container
            .select("g")
            .append("g")
            .attr("class", "x axis")
            .attr("transform", "translate(0," + height + ")")
            .call(xAxis); //draw x axis only at bottom

        svg.append("g")
            .attr("class", "y axis")
            .each(function(d, i) {
                var arr = [];
                for(var k in data) {
                    if(k === d) {
                        arr = data[k];
                    }
                }
                var max = findMaxY(arr);
                yScale.domain([0, max]);
                yAxis(d3.select(this));
            })
            .append("text")
            .attr("transform", "rotate(-90)")
            .attr("y", 6)
            .attr("x", -10)
            .attr("dy", ".71em")
            .style("text-anchor", "end")
            .text("");
    }

    //draw brush indicator
    function drawBrushIndicator() {

        ranges.forEach(function(d) {
            context.append("rect")
                .attr("class", "range_indicator")
                .attr("x", xScale2(d.start))
                .attr("width", (xScale2(d.end) < width ?
                        xScale2(d.end) : width) -
                    xScale2(d.start))
                .attr("height", height2)
                .attr("fill", "#6699FF");
        });
    }

    function drawLines() {
        issue = svg.selectAll(".issue")
            .data(function(k) {
                /*for (var k in data) {
                    if (k === d) {
                        var ret = {
                            name: k,
                            values: data[k]
                        };
                        console.log(ret);
                        return ret;
                    }
                }*/
                //options[k] = "value";
                return [{
                    name: k,
                    sampled: sampled[k],
                    values: data[k]
                }];

            }) // Select nested data and append to new svg group elements
            .enter()
            .append("g")
            .attr("class", "issue");

        issue.append("path")
            .attr("class", "line")
            .style("pointer-events", "none") // Stop line interferring with cursor
            .attr("id", function(d) {
                return "line-" + d.name.replace(" ", "").replace(
                    "/", ""); // Give line id of line-(insert issue name, with any spaces replaced with no spaces)
            })
            .attr("d", function(d) {
                var max = findMaxY(d.values);
                yScale.domain([0, max]);
                return line(d.values); //d.visible ? line(d.values) : null; // If array key "visible" = true then draw line, if not then don't 
            })
            .attr("clip-path", "url(#clip)") //use clip path to make irrelevant part invisible
            .style("stroke", function(d) {
                return color(d.name);
            });

        drawDots();

    }

    function drawDots() {
        // draw dots on blood pressure (discrete data) graph
        console.log("Draw Dots 1");
        if (data["blood_pressure"] !== undefined) {
            var max = findMaxY(data["blood_pressure"]);
            yScale.domain([0, max]);

            console.log("Draw Dots 2");
            issue
                .selectAll("circle")
                .data(function(d) {
                    if (d.name === "blood_pressure") {
                        return data[d.name];
                    } else {
                        return [];
                    }
                })
                .enter()
                .append("circle")
                .attr("class", "circles")
                .attr("fill",function(d) {
                    return color("blood_pressure");
                })
                .attr("r", 3)
                .attr("cx", function(d) {
                    return xScale(d.date);
                })
                .attr("cy", function(d) {
                    return yScale(d.value);
                })
                .attr("clip-path", "url(#clip)");
            console.log("Draw Dots 3");
        }
    }

    function drawLegend() {
        // draw legend
        legendSpace = height / 2; //height / categories.length; // 450/number of issues (ex. 40)    
        // changed from 450 to 250 for better appearance

        issue.append("rect")
            .attr("width", 10)
            .attr("height", 10)
            .attr("x", width + (margin.right / 3) - 15)
            .attr("y", function(d, i) {
                return(legendSpace) + i * (legendSpace) - 8;
            }) // spacing
            .attr("fill", function(d) {
                return color(d.name); //d.visible ? color(d.name) : "#F1F1F2"; // If array key "visible" = true then color rect, if not then make it grey 
            })
            .attr("class", function(d) {
                return "legend-box " + d.name.replace(" ", "").replace("/", "");
            })
            .attr("id", function(d) {
                return "button-" + d.name.replace(" ", "").replace("/", "") + "-value";
            })
            .attr("selected", true)
            /*.on("mouseover", function(d) {
                d3.select(this)
                    .transition()
                    .attr("fill", function(d) {
                        return color(d.name);
                    });

                d3.select("#line-" + d.name.replace(" ", "").replace(
                        "/", ""))
                    .transition()
                    .style("stroke-width", 2.5);
            })
            .on("mouseout", function(d) {
                d3.select(this)
                    .transition()
                    .attr("fill", function(d) {
                        return d.visible ? color(d.name) :
                            "#F1F1F2";
                    });

                d3.select("#line-" + d.name.replace(" ", "").replace(
                        "/", ""))
                    .transition()
                    .style("stroke-width", 1.5);
            })*/
            .on("click", clicked);

        //draw legend average / peak-to-peak / min-max options
        var options = ["average", "peak-to-peak", "min-max"];
        for(j = 0; j < 3; ++j) {
            issue.append("rect")
                .attr("width", 10)
                .attr("height", 10)
                .attr("x", width + (margin.right / 3) - 15)
                .attr("y", function(d, i) {
                    return(legendSpace) + i * (legendSpace) + 10 + j * 15;
                })
                .attr("fill", "#F1F1F2")
                .on("click", clicked)
                .attr("class", function(d) {
                    return "legend-box " + d.name.replace(" ", "").replace("/", "");
                })
                .attr("id", function(d) {
                    return "button-" + d.name.replace(" ", "").replace("/", "") + "-" + options[j];
                })
                .attr("selected", false);
        }

        issue.append("text")
            .attr("x", width + (margin.right / 3))
            .attr("y", function(d, i) {
                return(legendSpace) + i * (legendSpace);
            }) // (return (11.25/2 =) 5.625) + i * (5.625)
            .text(function(d) {
                if(d.sampled)
                    return d.name + "*";
                else
                    return d.name;
            });

        issue.append("text")
            .attr("x", width + (margin.right / 3))
            .attr("y", function(d, i) {
                return(legendSpace) + i * (legendSpace) + 18;
            }) // (return (11.25/2 =) 5.625) + i * (5.625) 
            .text("average");

        issue.append("text")
            .attr("x", width + (margin.right / 3))
            .attr("y", function(d, i) {
                return(legendSpace) + i * (legendSpace) + 33;
            }) // (return (11.25/2 =) 5.625) + i * (5.625) 
            .text("peak-to-peak");

        issue.append("text")
            .attr("x", width + (margin.right / 3))
            .attr("y", function(d, i) {
                return(legendSpace) + i * (legendSpace) + 48;
            }) // (return (11.25/2 =) 5.625) + i * (5.625) 
            .text("min-max");

    }

    function initializeTracker() {
        focus = svg // create group elements to house tooltip text
            .append("g") //create one <g> for each columnName
            .attr("class", "focus");

        focus.append("text") // http://stackoverflow.com/questions/22064083/d3-js-multi-series-chart-with-y-value-tracking
            .attr("class", "tooltip")
            .attr("x", width + 20) // position tooltips  
            .attr("y", legendSpace) // (return (11.25/2 =) 5.625) + i * (5.625) // position tooltips 
            .attr("id", function(d) {
                return "text-" + d.replace(" ", "").replace("/", "");
            })

        // Add mouseover events for hover line.
        d3.selectAll(".mouse-tracker") // select chart plot background rect .mouse-tracker
            .on("mousemove", mousemove) // on mousemove activate mousemove function defined below
            .on("mouseout", function() {
                hoverDate
                    .text(null); // on mouseout remove text for hover date
                focus.selectAll("text")
                    .text(null);

                d3.selectAll(".hover-line")
                    .style("opacity", 1e-6); // On mouse out making line invisible
            });
    }

    function clicked() {
        if(d3.select(this).attr("selected") === "false") {
            d3.selectAll("." + d3.select(this).attr("class").replace(" ", "."))
                .attr("fill", "#F1F1F2")
                .attr("selected", false); //clear all selections

            var name = d3.select(this).attr("class").replace("legend-box ", "");

            d3.select(this)
                .transition()
                .attr("fill", function() {
                    return color(name);
                });

            //make ajax call here
            var type = d3.select(this).attr("id").replace("button-" + name + "-", "");

            if(type === "value") {
                data[name] = backup[name];
                options[name] = "value";

                d3.select("#line-" + name.replace(" ", "").replace("/", ""))
                    //.transition()
                    .attr("d", function() {
                        //console.log(data[name]);
                        var max = findMaxY(data[name]);
                        yScale.domain([0, max]);
                        return line(data[name]); //d.visible ? line(d.values) : null; // If d.visible is true then draw line for this d selection
                    });

                drawDots();
                return;
            }

            $.ajax({
                type: "POST",
                url: '/data/update',
                data: {
                    patient: patient_id,
                    name: name,
                    option: type,
                    range: brush.empty() ? xScale2.domain() : brush.extent()
                },
                success: function(resp) {

                    if(backup[name] === undefined) {
                        backup[name] = data[name];
                    }

                    transformData(resp);

                    if (name === "blood_pressure" && type !== "value") {
                        d3.selectAll(".circles").remove();
                    }

                    d3.select("#line-" + name.replace(" ", "").replace("/", ""))
                        .transition()
                        .attr("d", function() {
                            //console.log(data[name]);
                            var max = findMaxY(backup[name]);
                            yScale.domain([0, max]);
                            return line(data[name]); //d.visible ? line(d.values) : null; // If d.visible is true then draw line for this d selection
                        });
                    //console.log(data);
                    /*switch(type) {
                        case "average":
                            updateData(data, name);
                            //chart.update();
                            //processData();
                            //console.log(categories);
                            //chart.render();
                            break;
                        case "peak-to-peak":
                            updateData(data, name);
                            break;
                        case "min-max":
                            updateData(data, name);
                            break;
                        default:
                            break;
                    }*/
                    //chart1.setData(data, true).update();
                }
            });

            d3.select(this).attr("selected", true);
        }
    }

    //helper methods
    function mousemove() {
        var mouse_x = d3.mouse(this)[0]; // Finding mouse x position on rect
        var graph_x = xScale.invert(mouse_x); //
        var format = d3.time.format('%a %b %Y %I:%M:%S.%L %p'); // Format hover date text to show three letter month and full year

        hoverDate.text(format(graph_x)); // scale mouse position to xScale date and format it to show month and year

        d3.selectAll(".hover-line") // select hover-line and changing attributes to mouse position
            .attr("x1", mouse_x)
            .attr("x2", mouse_x)
            .style("opacity", 1); // Making line visible

        for(var k in data) {
            dat = data[k];

            var x0 = xScale.invert(d3.mouse(this)[0]),
                /* d3.mouse(this)[0] returns the x position on the screen of the mouse. xScale.invert function is reversing the process that we use to map the domain (date) to range (position on screen). So it takes the position on the screen and converts it into an equivalent date! */
                i = bisectDate(dat, x0, 1), // use our bisectDate function that we declared earlier to find the index of our data array that is close to the mouse cursor
                /*It takes our data array and the date corresponding to the position of or mouse cursor and returns the index number of the data array which has a date that is higher than the cursor position.*/
                d0 = dat[i - 1],
                d1 = dat[i],
                d = 0;

            /*d0 is the combination of date and rating that is in the data array at the index to the left of the cursor and d1 is the combination of date and close that is in the data array at the index to the right of the cursor. In other words we now have two variables that know the value and date above and below the date that corresponds to the position of the cursor.*/
            if(d1 !== undefined) {
                d = x0 - d0.date > d1.date - x0 ? d1 : d0;
            }
            /*The final line in this segment declares a new array d that is represents the date and close combination that is closest to the cursor. It is using the magic JavaScript short hand for an if statement that is essentially saying if the distance between the mouse cursor and the date and close combination on the left is greater than the distance between the mouse cursor and the date and close combination on the right then d is an array of the date and close on the right of the cursor (d1). Otherwise d is an array of the date and close on the left of the cursor (d0).*/

            //d is now the data row for the date closest to the mouse position
            /*focus.select("text").text(function(columnName) {
            //because you didn't explictly set any data on the <text>
            //elements, each one inherits the data from the focus <g>
                return (d[columnName]);
            });*/
            $("#text-" + k.replace(" ", "").replace("/", ""))
                .text(d.value);

        }

    }

    //for brusher of the slider bar at the bottom
    function brushed() {
        //console.log("brushed");
        //algorithm to make ajax call:
        //once brushed, get the brush.extent(), and determine whether it is equal to
        //the entire range, in which case we do nothing. Else, find the smallest range that
        //encapsulates it (first find the start point, then loop through the array)
        //to find the ending point
        //then determine whether an ajax call is needed (by the ratio of brushed / range)
        //then making the ajax call, passing in the outer range & the brushed range and name of the line, and patient id
        //On server side, fetch the data and discard all data points out side the brushed range
        //then return the data and update the graph

        //only update when detail level < 10 seconds if 100 hz
        // < 4 seconds when 250 hz
        console.log(brush.extent());
        console.log("backup:");
        console.log(backup);

        xScale.domain(brush.empty() ? xScale2.domain() : brush.extent()); // If brush is empty then reset the Xscale domain to default, if not then make it the brush extent 

        svg.select(".x.axis") // replot xAxis with transition when brush used
            .transition()
            .call(xAxis);

        console.log("!!!!!!!!!");
        //console.log(data);
        for(var k in backup) {
            if(options[k] === "value") {
                data[k] = backup[k];
            }
        }

        issue.select("path") // Redraw lines based on brush xAxis scale and domain
            //.transition()
            .attr("d", function(d) {
                var max = 0;

                if(backup[d.name] !== undefined) {
                    max = findMaxY(backup[d.name]);
                } else {
                    max = findMaxY(data[d.name]);
                }
                yScale.domain([0, max]);
                console.log("STEP-1");
                return data[d.name] === undefined ? null : line(data[d.name]); //d.visible ? line(d.values) : null; // If d.visible is true then draw line for this d selection
            });
        
        d3.selectAll(".circles").remove();
        drawDots();

        console.log("STEP0");

        //if (!brush.empty()) {
        var extent = brush.empty() ? xScale2.domain() : brush.extent();
        if(extent[1].getTime() - extent[0].getTime() <= THRESHOLD) {
            // do work to show more detailed data
            for(i = 0; i < ajaxQueue.length; ++i) {
                ajaxQueue[i].abort();
            }

            ajaxQueue.push(
                $.ajax({
                    type: "POST",
                    url: '/data/brush',
                    data: {
                        patient: patient_id,
                        names: Object.keys(options),
                        options: options,
                        range: extent //brush.empty() ? xScale2.domain() : brush.extent()
                    },
                    success: function(resp) {
                        console.log(resp);
                        for(var name in data) {
                            if(backup[name] === undefined) {
                                backup[name] = data[name];
                            }
                        }
                        transformData(resp);
                        console.log(data);
                        d3.selectAll(".circles").remove();
                        issue.select("path") // Redraw lines based on brush xAxis scale and domain
                            //.transition()
                            .attr("d", function(d) {
                                var max = 0;

                                if(backup[d.name] !== undefined) {
                                    max = findMaxY(backup[d.name]);
                                } else {
                                    max = findMaxY(data[d.name]);
                                }
                                yScale.domain([0, max]);
                                console.log("STEP1");
                                return data[d.name] === undefined ? null : line(data[d.name]); //d.visible ? line(d.values) : null; // If d.visible is true then draw line for this d selection
                            });
                        drawDots();
                    }
                })
            );
        } else {
            /*for (var k in backup) {
                data[k] = backup[k];
            }
            issue.select("path")
                .transition()
                .attr("d", function(d) {
                    var max = findMaxY(data[d.name]);
                    yScale.domain([0, max]);
                    return data[d.name] === undefined ? null : line(data[d.name]);
                });*/
            var names = [];
            var alt_options = {};

            for(var k in options) {
                if(options[k] !== "value") {
                    names.push(k);
                    alt_options[k] = options[k];
                }
            }

            for(i = 0; i < ajaxQueue.length; ++i) {
                ajaxQueue[i].abort();
            }

            ajaxQueue.push(
                $.ajax({
                    type: "POST",
                    url: '/data/brush',
                    data: {
                        patient: patient_id,
                        names: names,
                        options: alt_options,
                        range: extent //brush.empty() ? xScale2.domain() : brush.extent()
                    },
                    success: function(resp) {
                        console.log(resp);
                        for(var name in data) {
                            if(backup[name] === undefined) {
                                backup[name] = data[name];
                            }
                        }
                        transformData(resp);
                        console.log(data);
                        d3.selectAll(".circles").remove();
                        issue.select("path") // Redraw lines based on brush xAxis scale and domain
                            //.transition()
                            .attr("d", function(d) {
                                var max = 0;

                                if(backup[d.name] !== undefined) {
                                    max = findMaxY(backup[d.name]);
                                } else {
                                    max = findMaxY(data[d.name]);
                                }
                                yScale.domain([0, max]);
                                console.log("STEP1");
                                return data[d.name] === undefined ? null : line(data[d.name]); //d.visible ? line(d.values) : null; // If d.visible is true then draw line for this d selection
                            });
                        drawDots();
                    }
                })
            );
        }
        //}

    }

    function findMaxY(dat) { // Define function "findMaxY"
        /*var maxYValueFromMean = (d3.mean(dat, function(d) { // Return max rating value
            //console.log(d);
            return parseInt(d.value);
        })) * 2;*/
        //console.log(dat);

        var minY = d3.min(dat, function(d) { // Return max rating value
            return +d.value; //convert string to number
        });
        var maxY = d3.max(dat, function(d) { // Return max rating value
            return +d.value;
        });

        maxY += (minY - 0);

        return maxY;

        /*if (maxYValueFromMax > maxYValueFromMean) {
            return maxYValueFromMax * 1.2;
        } else {
            return maxYValueFromMean;
        }*/

    }

    // evaluates an array in string format
    function evalStr(str) {
        if(str[0] !== "[" && str[str.length - 1] !== "]") {
            return str;
            //throw new Error("evalStr(): wrong string format, expected [a,b,c,...,x]");
        }

        str = str.substring(1, str.length - 1);

        if(str.indexOf(",") === -1) {
            str = [str];
        } else {
            str = str.split(",");
        }
        return str;
    }

    function getClosestDateRange(brushed) {
        if(ranges.length === 1) {
            return [ranges[0]["start"], ranges[0]["end"]];
        }

        var range = [],
            start = brushed[0],
            end = brushed[1];

        for(i = 0; i < ranges.length - 1; ++i) {
            if(ranges[i]["start"] <= start && ranges[i]["end"] >= start) {
                //data range encapsulates brushed range
                range.push(ranges[i]["end"]);
                break;
            } else if(ranges[i]["end"] < start && ranges[i + 1]["start"] > start) {
                //brushed range encapsulates data range
                range.push(ranges[i + 1]["start"]);
                break;
            }
        }

        for(i = 0; i < ranges.length - 1; ++i) {
            if(ranges[i]["start"] <= end && ranges[i]["end"] >= end) {
                //data range encapsulates brushed range
                range.push(ranges[i]["end"]);
                break;
            } else if(ranges[i]["end"] < end && ranges[i + 1]["start"] > end) {
                //brushed range encapsulates data range
                range.push(ranges[i]["end"]);
                break;
            }
        }
        return range;
    }

    return chart;
}