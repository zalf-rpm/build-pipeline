using System;
using System.Collections.Generic;
using System.IO;

namespace CoreConsoleParser.MonicaCSV
{
    public class CsvReader
    {
        public static List<CsvChapter> ReadCsvFile(string filename, out string error, bool debugOut = false, char seperatorCharacter = ',', char quotationCharacter = '\"')
        {
            error = string.Empty;
            List<CsvChapter> chapters = null;
            if (!File.Exists(filename))
            {
                error += string.Format("Error File not found: '{0}'", filename); 
                return null;
            }

            using (StreamReader reader = new StreamReader(filename))
            {
                chapters = new List<CsvChapter>();
                CsvChapter currentChapter = null;
                bool readColumnHeaderLine = false;
                bool readColumnInfoLine = false;
                bool startNewChapter = true;
                string line;
                while ((line = reader.ReadLine()) != null)
                {
                    if (string.IsNullOrWhiteSpace(line))
                    {
                        startNewChapter = true;
                        continue;
                    }
                    string[] tokens = CsvChapter.Split(line, seperatorCharacter, quotationCharacter);
                    if (tokens.Length == 1 && startNewChapter)
                    {
                        currentChapter = new CsvChapter
                        {
                            chapterName = tokens[0],
                            filePath = filename
                        };
                        chapters.Add(currentChapter);
                        readColumnHeaderLine = true;
                        startNewChapter = false;
                    }
                    else if (readColumnHeaderLine)
                    {
                        currentChapter.columnNames.AddRange(tokens);
                        readColumnHeaderLine = false;
                        readColumnInfoLine = true;
                    }
                    else if (readColumnInfoLine)
                    {
                        currentChapter.columnInfos.AddRange(tokens);
                        readColumnInfoLine = false;
                    }
                    else
                    {
                        List<string> row = new List<string>();
                        row.AddRange(tokens);
                        currentChapter.content.Add(row);
                    }
                }

                bool success = true;
                foreach (var chapter in chapters)
                {
                    if (debugOut) Console.WriteLine("Processed chapter {0}", chapter.chapterName);
                    success &= chapter.InitChapter(out string initErrorMsg);
                    if (!success)
                    {
                        error += initErrorMsg;
                        if (debugOut) Console.WriteLine("Error:");
                        if (debugOut) Console.WriteLine(initErrorMsg);
                        if (debugOut) Console.WriteLine("... failed");
                        continue;
                    }
                    success &= chapter.ProcessData(out string errorMsg);
                    if (!success)
                    {
                        error += errorMsg;
                        if (debugOut) Console.WriteLine("Error:");
                        if (debugOut) Console.WriteLine(errorMsg);
                        if (debugOut) Console.WriteLine("... failed");
                    }
                    else
                    {
                        if (debugOut) Console.WriteLine("... success", chapter.chapterName);
                    }
                }
            }
            return chapters;
        }

    }
}
