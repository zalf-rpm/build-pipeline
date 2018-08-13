using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Text.RegularExpressions;

namespace CoreConsoleParser.MonicaCSV
{
    public class CsvChapter
    {
        public string chapterName;
        public List<string> columnNames;
        public List<string> columnInfos;
        public DataTable dbTable;
        public List<List<string>> content;
        public string filePath;

        public CsvChapter()
        {
            this.chapterName = string.Empty;
            this.filePath = string.Empty;
            this.columnNames = new List<string>();
            this.columnInfos = new List<string>();
            this.content = new List<List<string>>();
        }

        public bool InitChapter(out string error)
        {
            error = string.Empty;
            bool noError = true;
            this.dbTable = new DataTable(this.chapterName);
            DataColumn indexColumn = new DataColumn
            {
                ColumnName = "Index",
                DataType = typeof(int),
                Caption = "Index",
                ReadOnly = true,
                AutoIncrement = true
            };
            dbTable.Columns.Add(indexColumn);
            this.dbTable.PrimaryKey = new DataColumn[] { indexColumn };

            if (this.columnNames.Count != this.columnInfos.Count)
            {
                noError = false;
                error += "list lenght of column names does not match number of descriptions\n";
            }
            for (int index = 0; index < this.columnNames.Count; index++)
            {
                string entry = this.columnNames[index] + this.columnInfos[index];
                Type defaultType = this.AnalyseForDataType(index);

                DataColumn column = new DataColumn
                {
                    ColumnName = entry,
                    DataType = defaultType,
                    Caption = entry,
                    ReadOnly = true,
                    AutoIncrement = false
                };
                dbTable.Columns.Add(column);
            }
            return noError;
        }

        public bool ProcessData(out string errorMsg)
        {
            bool success = true;
            errorMsg = string.Empty;
            foreach (var row in content)
            {
                bool skipRow = false;
                DataRow dataRow = this.dbTable.NewRow();
                for (int i = 1; i < this.dbTable.Columns.Count; i++)
                {
                    string errMsg;
                    object val = ParseDataValue(row[i - 1], this.dbTable.Columns[i].DataType, out errMsg);
                    if (val != null)
                    {
                        dataRow[i] = val;
                    }
                    else
                    {
                        errorMsg += errMsg;
                        skipRow = true;
                        success = false;
                    }
                }
                if (!skipRow)
                {
                    this.dbTable.Rows.Add(dataRow);
                }
            }
            if (success)
            {
                // clear data
                this.content.Clear();
            }
            return success;
        }

        public static string[] Split(string text, char delimiter = ',', char quoteChar = '\"')
        {
            string pattern = string.Format(@"{0}(?=(?:[^{1}]*{1}[^{1}]*{1})*(?![^{1}]*{1}))",
                        Regex.Escape(delimiter.ToString()),
                        Regex.Escape(quoteChar.ToString()));

            string[] result = Regex.Split(text, pattern, RegexOptions.Compiled);

            return result;
        }

        private Type AnalyseForDataType(int columnIndex)
        {
            Type defaultType = typeof(string);
            bool isDigit = true;
            bool isStdDate = true;
            bool analyseOccured = false;
            foreach (var row in this.content)
            {
                if (columnIndex < row.Count)
                {
                    analyseOccured = true;
                    if (string.IsNullOrWhiteSpace(row[columnIndex]))
                    {
                        isDigit = false;
                        isStdDate = false;
                    }
                    if (isDigit)
                    {
                        isDigit = Regex.IsMatch(row[columnIndex], @"(^[-+]?\d+(\.\d+)?$)", RegexOptions.Compiled);
                    }
                    if (!isDigit && isStdDate)
                    {
                        isStdDate = Regex.IsMatch(row[columnIndex], @"[0-9]{4}-[0-2][0-9]-[0-3][0-9]", RegexOptions.Compiled);
                    }
                    if (!isDigit && !isStdDate)
                    {
                        // neither date nor digit -> type is string
                        break;
                    }
                }
            }
            if (analyseOccured)
            {
                if (isDigit) return typeof(double);
                if (isStdDate) return typeof(DateTime);
            }
            return defaultType;
        }

        private static object ParseDataValue(string value, Type expectedType, out string errorMsg)
        {
            errorMsg = string.Empty;
            object defValue = null;
            if (expectedType == typeof(string))
            {
                defValue = value;
            }
            else if (!string.IsNullOrWhiteSpace(value))
            {
                if (expectedType == typeof(double))
                {
                    NumberFormatInfo numFormat = (System.Globalization.NumberFormatInfo)System.Globalization.CultureInfo.InstalledUICulture.NumberFormat.Clone();
                    numFormat.NumberDecimalSeparator = ".";
                    double result = 0;
                    if (double.TryParse(value, NumberStyles.Float, numFormat, out result))
                    {
                        return result;
                    }
                    errorMsg = string.Format("Failed to parse number: '{0}'", value);
                }
                else if (expectedType == typeof(DateTime))
                {
                    try
                    {
                        DateTime date = DateTime.ParseExact(value, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
                        return date;
                    }
                    catch (FormatException)
                    {
                        errorMsg = string.Format("Format Error: Failed to parse Date: '{0}'", value);
                    }
                }
            }
            return defValue;
        }
    }
}
