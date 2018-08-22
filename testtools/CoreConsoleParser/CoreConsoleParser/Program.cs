using CoreConsoleParser.MonicaCSV;
using System;
using System.Collections.Generic;

namespace CoreConsoleParser
{
    class Programm
    {
        static int Main(string[] args)
        {
            string referenceFilename = "";
            string toTestFilename = "";
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "-ref" && i + 1 < args.Length)
                {
                    referenceFilename = args[i + 1];
                }
                if (args[i] == "-totest" && i + 1 < args.Length)
                {
                    toTestFilename = args[i + 1];
                }
            }
            if (string.IsNullOrWhiteSpace(referenceFilename) || string.IsNullOrWhiteSpace(toTestFilename))
            {
                Console.WriteLine(  "2 monica out csv files required to compare. \n" +
                                    "Pleas specify -ref <path to reference> -totest <path to test file>");
                Environment.Exit(3);
            }

            // read files
            List<CsvChapter> refChapters = CsvReader.ReadCsvFile(referenceFilename, out string errorReadRef, true);
            List<CsvChapter> testChapters = CsvReader.ReadCsvFile(toTestFilename, out string errorReadTest, true);
            if (refChapters != null && testChapters != null)
            {
                bool success = true;
                if (!string.IsNullOrWhiteSpace(errorReadRef))
                {
                    Console.WriteLine(errorReadRef);
                }
                if (!string.IsNullOrWhiteSpace(errorReadTest))
                {
                    Console.WriteLine(errorReadTest);
                }
                CsvComparer csvComparer = new CsvComparer()
                {
                    referenceChapters = refChapters,
                    csvToTestChapters = testChapters
                };
                // compare values
                success &= csvComparer.Compare(out string error, out string warning);
                // print out errors and warnings that occured
                if (!string.IsNullOrWhiteSpace(warning))
                {
                    Console.WriteLine("Warning:");
                    Console.WriteLine(warning);
                }
                if (!string.IsNullOrWhiteSpace(error))
                {
                    Console.WriteLine("Errors:");
                    Console.WriteLine(error);
                }

                if (!success)
                {
                    Environment.Exit(1);
                }
            }
            else
            {
                // exit could not open file
                if (refChapters == null) Console.WriteLine("Failed to open '{0}'", referenceFilename);
                if (testChapters == null) Console.WriteLine("Failed to open '{0}'", toTestFilename);

                Environment.Exit(3);
            }
            Environment.Exit(1);// test for jenkins failue script
            Console.WriteLine("No significant changes detected");
            return 0;
        }
    }
}
