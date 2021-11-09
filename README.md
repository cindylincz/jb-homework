# Homework Result

## Task 1: Data quality – the difference between NetSuite ERP and payment gateway

### Output

- csv. Files

  The files of **the transactions which are unable to be matched**. They can be found in the folder **Task1**. 

  - Task1_Output
    
    A aggregated list of both Settlement and NetSuite data (partial info provided) on order level
  
  - Task1_Output_NetSuite

    A list of NetSuite data (partial info provided) on transaction level

  - Task1_Output_Settlement

    A list of Settlement data on transaction level
      
- SQL tables

  The source tables for the csv. files mentioned above are stored in the SQL server.
  
  - [dbnine].[dbo].[task1_output]
  - [dbnine].[dbo].[task1_output_netsuite]
  - [dbnine].[dbo].[task1_output_settlement]

- R script
  
  The codes are run for loading and combine the files of Settlement data
  
  ```
  library(readr)
  library(dplyr)

  files <- list.files(path = "settlement", pattern = "*.csv", full.names = T)
  data <- lapply(files, read_delim, delim = ";", locale = locale(decimal_mark = ".")) %>% 
    bind_rows()

  write.csv2(data, file = "settlement_data.csv", row.names = FALSE)
  ```
  
- SQL script 

  The script used for all the data preparation, analysis and troubleshooting. The script can be found in the folder **Task1**.

### Finding

Below are the summary of the discrepany causes and solutions (if any):

- Merchant Account **JetBrainsAmericasUSD** with batch no. 139, 141 and missing batch no.

  NetSuite transactions with missing batch no. can be fully matched to Settlement data in batch 139 and 141.
  As long as the batch no. can be updated in those NetSuite transactions, the discrepancy will disappear.

- Merchant Account **JetBrainsEUR** with batch no. 138

  The difference comes from the NET amount in Settlement data.
  In NetSuite data the transactions from account 315700 (JBCZ: Receivables against ADYEN-EUR) are missing.
  
- Merchant Account **JetBrainsEUR** with batch no. 139

  43 order refunds in Settlement data are missing in NetSuite.
  In addition, out of the missing NetSuite data there are 4 orders settled in batch 138, and their records don't exist in batch 139.

- Merchant Account **JetBrainsGBP** with batch no. 141

  The order ref. in this batch are unfortuantely not found in NetSuite data. Further analysis is needed.

### Solving Process

#### Data Preparation

Firstly, both Settlement and NetSuite data should be cleaned and loaded correctly, and the relations between tables should be clarified. The further analysis can be carried on only when the data is good to use.

1. Load Settlement Data 
   
   Download the settlement data from GitHub, then load and combine the files into one through R. Lastly, upload the combined settlement data to the server: [dbnine].[dbo].[settlement_data]

2. Extract NetSuite Data 
   
   Check all NetSuite tables and data availability, and extract the essential data to the table: [dbnine].[dbo].[netsuite]

3. Make Sure Both Datasets Are Ready to Use 
   
   Use two tables created in previous steps and create the overall comparison table. 
   
   If the output is the same as the table provided by the accouting department, it implies the settlement data is parsed and loaded correctly, and the conditions applied for NetSuite data are correct as well. 
   
   If the result is different, then modify the conditions/tables used in previous steps (if needed).

#### Data Analysis

This section the lists are created as requested, and the troubleshooting process for discrepancies between tables are provided too.

1. Generate Output Files

   The files have been uploaded to the folder **Task1** on either transaction level or aggregated order level. The source tables are stored in the server too. 

2. Troubleshooting

   The discrepancies are caused by different reasons. Based on the amount difference, there are 3 issues identified and will be analyzed separately.
   
3. Solution
   
   Based on the findings in troubleshooting process, the possible solutions for fixing the discrepancy issues are suggested. 
