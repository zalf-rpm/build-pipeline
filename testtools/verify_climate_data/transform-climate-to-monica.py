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

def main():
    
  def transformClimate(pathToFile, pathToOutput):
    filename = os.path.split(pathToFile)[1]

    with open(pathToFile) as f:
      reader = csv.reader(f, delimiter=";")
      next(reader)
      of = None
      currFile = ""
      # GRID_NO          grid ID format row column -> (rr)rccc
      # LATITUDE         latitude
      # LONGITUDE        longitude
      # ALTITUDE         altitude
      # DAY              date in format yyyymmdd
      # TEMPERATURE_MAX  maximum air temperature (°C)
      # TEMPERATURE_MIN  minimum air temperature (°C)
      # TEMPERATURE_AVG  mean air temperature (°C)
      # WINDSPEED        mean daily wind speed at 10m (m/s)
      # VAPOURPRESSURE   vapour pressure (hPa)
      # PRECIPITATION    sum of precipitation (mm/day)
      # RADIATION        total global radiation (KJ/m2/day)

      fullPathToOutputDir = os.path.join(pathToOutput, "historical")
      if not os.path.exists(fullPathToOutputDir):
        os.makedirs(fullPathToOutputDir)

      csvHeader = ["iso-date", "tmin", "tavg", "tmax", "precip", "globrad", "wind", "relhumid", "vaporpress"]
      csvUnits = ["-", "°C", "°C", "°C", "mm", "MJ m-2", "m s-1", "% 0-100", "kPa"]
      for row in reader:
        rowID, colID = row[0][:-3], row[0][-3:]
        outFilename = str(rowID)+ "_"+str(colID)

        def relHum(T, Pw) :
          A = 6.116441
          m = 7.591386
          Tn = 240.7263
          Pws = A * 10**(m * T / (T + Tn))
          return (Pw / Pws) *100 

        vp = float(row[9])
        tmin = float(row[6])
        tmax = float(row[5])
        relHumMin = relHum(tmin, vp)
        relHumMax = relHum(tmax, vp)
        relHumAvg = round( ( relHumMin + relHumMax ) / 2, 1)

        line = [
          datetime.datetime.strptime(row[4], "%Y%m%d").date().isoformat() 
          , tmin 
          , float(row[7]) 
          , tmax 
          , float(row[10]) 
          , round(float(row[11]) / 1000, 1)
          , float(row[8])
          , relHumAvg
          , float(row[9])
          ]

        if currFile != outFilename :
          if of != None:
            of.close()
          currFile = outFilename

          of = open(os.path.join(fullPathToOutputDir, outFilename + ".csv"), 'wt', newline="")
          writer = csv.writer(of, delimiter = ",")
          writer.writerow(csvHeader)
          writer.writerow(csvUnits)
      
        writer.writerow(line)

      if of != None:
        of.close()		

  #pathToClimateCSVs = "./original"
  #pathToOutput = "./transformed/"

  pathToClimateCSVs = "."
  pathToOutput = "./transformed/"

  files = os.listdir(pathToClimateCSVs)
  print("read directory ...")
  for f in files:
    fullPath = os.path.join(pathToClimateCSVs, f)
    
    if os.path.isfile(fullPath):
      transformClimate(fullPath, pathToOutput)
      print("transformed ", f )

if __name__ == '__main__':
    main()