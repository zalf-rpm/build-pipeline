#!/usr/bin/python3
# -*- coding: UTF-8

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/. */

# Authors:
# Michael Berg-Mohnicke <michael.berg@zalf.de>
#
# Maintainers:
# Currently maintained by the authors.
#
# This file has been created at the Institute of
# Landscape Systems Analysis at the ZALF.
# Copyright (C: Leibniz Centre for Agricultural Landscape Research (ZALF)

import csv
import os
import datetime
import errno
import math as m

csvHeader = ["iso-date", "tmin", "tavg", "tmax", "precip", "globrad", "wind", "relhumid", "vaporpress", "dewpoint_temp","relhumid_tmin","relhumid_tmax"]
csvUnits = ["-", "°C", "°C", "°C", "mm", "MJ m-2", "m s-1", "% 0-100", "kPa","°C","% 0-100","% 0-100"]

def main():

  origSource = "C:/Users/sschulz/go/src/github.com/zalf-rpm/soybean-EU/missingregions.csv"
  origSourceTransform = "C:/Users/sschulz/go/src/github.com/zalf-rpm/soybean-EU/climate-data/rel_hum_test/0/0_0"
  #pathToClimateCSVs = "C:/Users/sschulz/go/src/github.com/zalf-rpm/soybean-EU/climate-data/corrected/0/0_0"
  #outPath = "C:/Users/sschulz/go/src/github.com/zalf-rpm/soybean-EU/climate-data/rel_hum_test/compared"
  # read missingregions.csv
  

  currentFilename = ""
  climoutfile = None
  with open(origSource) as sourcefile:
    firstLine = True
    header = dict()
    for line in sourcefile:
      if firstLine :
        firstLine = False
        tokens = line.split(",")
        i = -1
        for token in tokens :
          token = token.strip('\n')
          token = token.strip('\"')
          token = token.strip()
          i = i+1
          header[token] = i
        continue

      #"GRID_NO","LATITUDE","LONGITUDE","ALTITUDE","DAY","TEMPERATURE_MAX","TEMPERATURE_MIN","TEMPERATURE_AVG","WINDSPEED","VAPOURPRESSURE","PRECIPITATION","RADIATION"
      tokens = line.split(",")
      gridIdx = tokens[header["GRID_NO"]] 
      row = gridIdx[:-3]
      col = gridIdx[-3:]
      new_filename = row +"_" + col +"_v3test.csv"
      if climoutfile != None and currentFilename != new_filename :
        climoutfile.close()
      if currentFilename != new_filename :
        out_path = os.path.join(origSourceTransform, new_filename)
        makeDir(out_path)
        climoutfile = open(out_path, mode="wt", newline="") 
        currentFilename = new_filename
        writer = csv.writer(climoutfile, delimiter = ",")
        writer.writerow(csvHeader)
        writer.writerow(csvUnits)
    
      #  "iso-date", "tmin", "tavg", "tmax", "precip", "globrad", "wind", "relhumid", "vaporpress","dewpoint_temp","relhumid_tmin","relhumid_tmax"
      isodateStr = tokens[header["DAY"]] 
      isodate = isodateStr[:4] + "-" + isodateStr[4:6] + "-" + isodateStr[6:8]
      tmin = float(tokens[header["TEMPERATURE_MIN"]])
      tavg = tokens[header["TEMPERATURE_AVG"]] 
      tmax = float(tokens[header["TEMPERATURE_MAX"]] )
      if tmin > tmax :
        tmin, tmax = tmax, tmin
      precip = tokens[header["PRECIPITATION"]] 
      globrad = tokens[header["RADIATION"]]      
      wind = float(tokens[header["WINDSPEED"]]) 
      vaporpress = float(tokens[header["VAPOURPRESSURE"]] ) / 10

      #TODo 
      def e0(temp) :
        return 0.6108 * m.exp(17.27 * temp / (temp + 237.3))

      e0tmax = e0(tmax)
      e0tmin  = e0(tmin)      
      vaporpressDewPoint = vaporpress # e0(tmax)
      tdew = (116.91 + 237.3 * m.log(vaporpressDewPoint))/ (16.78 -m.log(vaporpressDewPoint))
      relHum_max = min(100, 100 * vaporpressDewPoint / e0tmax)
      relHum_min = min(100, 100 * vaporpressDewPoint / e0tmin)
      relHum_Avg = min(100, (relHum_max + relHum_min ) /2 )

      if relHum_Avg < 10:
        print("low relHum", isodate,vaporpressDewPoint, precip, tmax, tmin,  relHum_max, relHum_min, relHum_Avg)
        # vaporpressDewPoint = e0tmin
        # tdew = (116.91 + 237.3 * m.log(vaporpressDewPoint))/ (16.78 -m.log(vaporpressDewPoint))
        # relHum_max = min(100, 100 * vaporpressDewPoint / e0tmax)
        # relHum_min = min(100, 100 * vaporpressDewPoint / e0tmin)
        # relHum_Avg = min(100, (relHum_max + relHum_min ) /2 )

      if 100 * vaporpressDewPoint / e0tmax  < 100 and 100 * vaporpressDewPoint / e0tmin < 100 :
        vaporpressDewPoint2 = 2 * relHum_Avg * e0tmin / (100 * (1 + e0tmin/e0tmax) )
        tdew2 = (116.91 + 237.3 * m.log(vaporpressDewPoint2))/ (16.78 -m.log(vaporpressDewPoint2))
        relHum_max2 = min(100, 100 * vaporpressDewPoint2 / e0tmax)
        relHum_min2 = min(100, 100 * vaporpressDewPoint2 / e0tmin)



      line = [
        isodate
        , tmin
        , tavg 
        , tmax
        , precip
        , round(float(globrad) / 1000, 1)
        , wind
        , "{:.1f}".format(relHum_Avg)
        , "{:.2f}".format(vaporpressDewPoint )
        , "{:.1f}".format(tdew)
        ,"{:.1f}".format( relHum_min)
        , "{:.1f}".format(relHum_max)
        ]

      writer.writerow(line)




  # extract grid_no 
  #  "iso-date", "tmin", "tavg", "tmax", "precip", "globrad", "wind", "relhumid", "vaporpress"
  # calculate relhumid

  # find corresponding grids
  # compare relhumid and vaporpress

  # cmd out count differences vs total
  # stddev max, min
  # files out  grid, their relhumid, their vaporpress, my relhumid, my vaporpress, 

  #pathToClimateCSVs = "./original"
  #pathToOutput = "./transformed/"

#   pathToClimateCSVs = "C:/Users/sschulz/go/src/github.com/zalf-rpm/soybean-EU/missingregions.csv"
#   pathToOutput = "./test_rel_hum/"

#   files = os.listdir(pathToClimateCSVs)
#   print("read directory ...")
#   for f in files:
#     fullPath = os.path.join(pathToClimateCSVs, f)
    
#     if os.path.isfile(fullPath):
#       transformClimate(fullPath, pathToOutput)
#       print("transformed ", f )

# def transformClimate(pathToFile, pathToOutput):
#   filename = os.path.split(pathToFile)[1]

#   with open(pathToFile) as f:
#     reader = csv.reader(f, delimiter=";")
#     next(reader)
#     of = None
#     currFile = ""
#     # GRID_NO          grid ID format row column -> (rr)rccc
#     # LATITUDE         latitude
#     # LONGITUDE        longitude
#     # ALTITUDE         altitude
#     # DAY              date in format yyyymmdd
#     # TEMPERATURE_MAX  maximum air temperature (°C)
#     # TEMPERATURE_MIN  minimum air temperature (°C)
#     # TEMPERATURE_AVG  mean air temperature (°C)
#     # WINDSPEED        mean daily wind speed at 10m (m/s)
#     # VAPOURPRESSURE   vapour pressure (hPa)
#     # PRECIPITATION    sum of precipitation (mm/day)
#     # RADIATION        total global radiation (KJ/m2/day)

#     fullPathToOutputDir = os.path.join(pathToOutput, "historical")
#     if not os.path.exists(fullPathToOutputDir):
#       os.makedirs(fullPathToOutputDir)

#     csvHeader = ["iso-date", "tmin", "tavg", "tmax", "precip", "globrad", "wind", "relhumid", "vaporpress"]
#     csvUnits = ["-", "°C", "°C", "°C", "mm", "MJ m-2", "m s-1", "% 0-100", "kPa"]
#     for row in reader:
#       rowID, colID = row[0][:-3], row[0][-3:]
#       outFilename = str(rowID)+ "_"+str(colID)

#       def relHum(T, Pw) :
#         A = 6.116441
#         m = 7.591386
#         Tn = 240.7263
#         Pws = A * 10**(m * T / (T + Tn))
#         return (Pw / Pws) *100 

#       vp = float(row[9])
#       tmin = float(row[6])
#       tmax = float(row[5])
#       relHumMin = relHum(tmin, vp)
#       relHumMax = relHum(tmax, vp)
#       relHumAvg = round( ( relHumMin + relHumMax ) / 2, 1)

#       line = [
#         datetime.datetime.strptime(row[4], "%Y%m%d").date().isoformat() 
#         , tmin 
#         , float(row[7]) 
#         , tmax 
#         , float(row[10]) 
#         , round(float(row[11]) / 1000, 1)
#         , float(row[8])
#         , relHumAvg
#         , float(row[9])
#         ]

#       if currFile != outFilename :
#         if of != None:
#           of.close()
#         currFile = outFilename

#         of = open(os.path.join(fullPathToOutputDir, outFilename + ".csv"), 'wt', newline="")
#         writer = csv.writer(of, delimiter = ",")
#         writer.writerow(csvHeader)
#         writer.writerow(csvUnits)
    
#       writer.writerow(line)

#     if of != None:
#       of.close()		

def makeDir(out_path) :
    if not os.path.exists(os.path.dirname(out_path)):
        try:
            os.makedirs(os.path.dirname(out_path))
        except OSError as exc: # Guard against race condition
            if exc.errno != errno.EEXIST:
                raise

if __name__ == '__main__':
    main()