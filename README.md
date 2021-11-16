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

  The script **Task1** used for all the data preparation, analysis and troubleshooting. It can be found in the folder **Task1**.

### Finding & Solution

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



## Task 2: Sale analysis – revenue decline in ROW region

### Output

- Power BI dashboard (in both PDF and .pbix format)

  The dashboard is created to illustrate the issue and proposed solution better.
  
  - Task2_Sales.pbix
  
  - Task2_Sales.pdf

### Finding & Solution

- The performance is mainly affected by the change in exchange rate of EUR and GBP. If taking the original sales values (not converted to USD), there is growth in sales in 2019H1 in comparison with 2018H1.

- The suggestion would be to use one fixed exchange rate (e.g. the rates as of the reporting date) while comparing the sales in ROW and US. By doing so the changes in rates will not be reflected in the report and the original sales trend can be kept.  

### Solving Process

#### Data Preparation

Lookup tables are directly loaded directly to the Power BI. To keep the performance, only essential fields from Order table (together with the partial information of rates and order items) is loaded and used in the dashboard.

#### Data Analysis

1. There were declines in sales amount in all months in 2019H1. However, without currency conversion the sales performance actually was not bad in 2019H1. Thus the cause could most likely be the exchange rate. 

2. After checking the trend in exchange rates of EUR and GBP, the rates in 2019 were overall higher than in 2018, which led to the lower USD value after conversion. 

3. To avoid the effect from exchange rates, the fixed rates (instead of using daily rates) can be applied in the report. The trend in original values can be kept and at the same time the performance can be compared with US market.
