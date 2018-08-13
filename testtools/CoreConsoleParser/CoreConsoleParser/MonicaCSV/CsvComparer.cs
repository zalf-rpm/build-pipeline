using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace CoreConsoleParser.MonicaCSV
{
    class CsvComparer
    {
        public List<CsvChapter> referenceChapters;
        public List<CsvChapter> csvToTestChapters;
        public double Epsilon = 0.00000001;

        public CsvComparer()
        {
            this.referenceChapters = new List<CsvChapter>();
            this.csvToTestChapters = new List<CsvChapter>();
        }

        public bool Compare(out string error, out string warning)
        {
            bool noIssues = true;
            error = string.Empty;
            warning = string.Empty;
            int numErrors = 0;
            int numWarnings = 0;

            foreach (var refChapter in referenceChapters)
            {
                string refName = refChapter.chapterName;

                CsvChapter testChapter = this.csvToTestChapters.Find(c => c.chapterName == refName);
                // check if new file has the same chapters
                if (testChapter != null)
                {
                    bool hasEqualNumberOfRows = testChapter.dbTable.Rows.Count == refChapter.dbTable.Rows.Count;
                    if (!hasEqualNumberOfRows)
                    {
                        error += string.Format("Number of rows not matching for table {0}: is {1} should be {2}\n", 
                                                refName,
                                                testChapter.dbTable.Rows.Count,
                                                refChapter.dbTable.Rows.Count);
                        numErrors++;
                    }
                    foreach (DataColumn column in refChapter.dbTable.Columns)
                    {
                        // check for the same column name
                        if (-1 == testChapter.dbTable.Columns.IndexOf(column.ColumnName))
                        {
                            error += string.Format("Missing Column: {0} \n", column.ColumnName);
                            numErrors++;
                        }
                        else
                        {
                            // check for the same column datatypes
                            Type oldType = column.DataType;
                            Type newType = testChapter.dbTable.Columns[column.ColumnName].DataType;
                            if (oldType != newType)
                            {
                                error += string.Format("DataType of Column changed in table {0} from {1} to {2}\n", refName, oldType.ToString(), newType.ToString());
                                numErrors++;
                            }
                            else if (hasEqualNumberOfRows)
                            {
                                for (int idxRow = 0; idxRow < refChapter.dbTable.Rows.Count; idxRow++)
                                {
                                    var rowRef = refChapter.dbTable.Rows[idxRow];
                                    var rowTest = testChapter.dbTable.Rows[idxRow];

                                    if (column.DataType == typeof(Double))
                                    {
                                        double valueOld = (double)rowRef[column.ColumnName];
                                        double valueNew = (double)rowTest[column.ColumnName];
                                        if (Math.Abs(valueOld - valueNew) > Epsilon)
                                        {
                                            error += string.Format("DataSet difference at (Capt:{0}|Col:{1}|line:{2}) from {3} to {4}\n",
                                                                    refName,
                                                                    column.ColumnName,
                                                                    idxRow,
                                                                    rowRef[column.ColumnName],
                                                                    rowTest[column.ColumnName]);
                                            numErrors++;
                                        }
                                    }
                                    else
                                    {
                                        if (!rowRef[column.ColumnName].Equals(rowTest[column.ColumnName]))
                                        {
                                            error += string.Format("DataSet difference at (Capt:{0}|Col:{1}|line:{2}) from {3} to {4}\n", 
                                                                    refName,
                                                                    column.ColumnName,
                                                                    idxRow,
                                                                    rowRef[column.ColumnName], 
                                                                    rowTest[column.ColumnName]);
                                            numErrors++;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if (refChapter.columnNames.Count < testChapter.columnNames.Count)
                    {
                        warning += string.Format("Added column(s) to {0}\n", refName);
                        numWarnings++;
                    }
                    
                }
                else
                {
                    error += string.Format("Missing Chapter: {0}\n", refName);
                    numErrors++;
                }
            }

            // check if new file has more chapters
            if (csvToTestChapters.Count > referenceChapters.Count)
            {
                warning += string.Format("Added Chapter(s)\n");
                numWarnings++;
            }
            if (numWarnings > 0)
            {
                warning += string.Format("WARNINGS:{0}", numWarnings);
            }
            if (numErrors > 0)
            {
                error += string.Format("ERRORS:{0}", numErrors);
            }
            noIssues = numErrors == 0;
            return noIssues;
        }
    }
}
