/*********************************************************************************** 

1. DATA PREPARATION

Firstly, the aggrgated settlement data (by R) is loaded to SQL server. 
All the netsuite tables are checked and the essential data is extracted. 

Once the output is the same as from accouting department, it implies the 
settlement data is parsed and loaded successfully, and the conditions 
applied for NetSuite data are correct as well.

Data can only be analyzed after this preparation stage.

***********************************************************************************/

-- 1.1 Get NetSuite data 

select distinct
	acc.ACCOUNTNUMBER,
	t.MERCHANT_ACCOUNT,
	t.BATCH_NUMBER,
	t.ORDER_REF,
	t.TRANDATE,
	tl.AMOUNT,
	tl.AMOUNT_FOREIGN
into [dbnine].[dbo].[netsuite]
from [bi].[netsuite].[ACCOUNTS] acc
join [bi].[netsuite].[TRANSACTION_LINES] tl on acc.ACCOUNT_ID = tl.ACCOUNT_ID
join [bi].[netsuite].[TRANSACTIONS] t on tl.TRANSACTION_ID = t.TRANSACTION_ID
where 
	acc.ACCOUNTNUMBER in ('315700','315710','315720','315800','548201')
	and tl.TRANSACTION_LINE_ID <> 0;

-- 1.2 Create the aggregated data on order level in each account and batch 

select 
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF,
	sum(GROSS) as GROSS
into #order_pg
from [dbnine].[dbo].[settlement_data]
group by
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF;

select 
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF,
	sum(AMOUNT_FOREIGN) as AMOUNT_FOREIGN
into #order_ns
from [dbnine].[dbo].[netsuite]
group by
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF;


-- 1.3 Compare the output with the data from the accouting dep.

with #sum_pg as (
select 
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	sum(GROSS) as GROSS
from #order_pg
group by
	MERCHANT_ACCOUNT,
	BATCH_NUMBER
)
, #sum_ns as (
select 
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	sum(AMOUNT_FOREIGN) as AMOUNT_FOREIGN
from #order_ns
group by
	MERCHANT_ACCOUNT,
	BATCH_NUMBER
)
select 
	coalesce(a.MERCHANT_ACCOUNT, b.MERCHANT_ACCOUNT) as MERCHANT_ACCOUNT,
	coalesce(a.BATCH_NUMBER, b.BATCH_NUMBER) as BATCH_NUMBER,
	coalesce(a.AMOUNT_FOREIGN, 0) as AMOUNT_FOREIGN,
	coalesce(b.GROSS, 0) as GROSS,
	coalesce(a.AMOUNT_FOREIGN, 0) - coalesce(b.GROSS, 0) as Amount_Diff
from #sum_ns a 
full join #sum_pg b on a.MERCHANT_ACCOUNT = b.MERCHANT_ACCOUNT and a.BATCH_NUMBER = b.BATCH_NUMBER
order by b.MERCHANT_ACCOUNT, b.BATCH_NUMBER;



/***********************************************************************************

2. DATA ANALYSIS 

Now the data is ready. 
Lists of orders which are failed to be matched can be created.

For troubleshooting, based on the previous output, there are 3 types of issues:

1. No batch no. in NetSuite (JetBrainsAmericasUSD account only)
2. With batch no., but no data in NetSuite
3. With batch no. and data in NetSuite, but the amount doesn't match

***********************************************************************************/


-- 2.1 Create a list of orders which are failed to be matched 

---- 2.1.1 overall aggregated data on order level

select 
	a.*, 
	b.MERCHANT_ACCOUNT as MERCHANT_ACCOUNT_PG,
	b.BATCH_NUMBER as BATCH_NUMBER_PG,
	b.ORDER_REF as ORDER_REF_PG,
	b.GROSS
into [dbnine].[dbo].[task1_output]
from #order_ns a 
full join #order_pg b on 
	a.MERCHANT_ACCOUNT = b.MERCHANT_ACCOUNT 
	and a.BATCH_NUMBER = b.BATCH_NUMBER 
	and a.ORDER_REF = b.ORDER_REF
where a.MERCHANT_ACCOUNT is null or b.MERCHANT_ACCOUNT is null or a.AMOUNT_FOREIGN <> b.GROSS
order by a.MERCHANT_ACCOUNT, a.BATCH_NUMBER, b.MERCHANT_ACCOUNT, b.BATCH_NUMBER;

---- 2.1.2 netsuite data on transaction level

select a.* 
into [dbnine].[dbo].[task1_output_netsuite]
from [dbnine].[dbo].[netsuite] a
join [dbnine].[dbo].[task1_output] b on 
	a.MERCHANT_ACCOUNT = b.MERCHANT_ACCOUNT 
	and (a.BATCH_NUMBER = b.BATCH_NUMBER or a.BATCH_NUMBER is null)  
	and a.ORDER_REF = b.ORDER_REF;

---- 2.1.3 settlement data on transaction level

select a.* 
into [dbnine].[dbo].[task1_output_settlement]
from [dbnine].[dbo].[settlement_data] a
join [dbnine].[dbo].[task1_output] b on 
	a.MERCHANT_ACCOUNT = b.MERCHANT_ACCOUNT_PG 
	and (a.BATCH_NUMBER = b.BATCH_NUMBER_PG or a.BATCH_NUMBER is null)  
	and a.ORDER_REF = b.ORDER_REF_PG
order by a.MERCHANT_ACCOUNT, a.BATCH_NUMBER;

-- 2.2 Troubleshoot 

---- 2.2.1 No batch no. in NetSuite (JetBrainsAmericasUSD account only)

/* 

Since the difference of sum amount (in JetBrainsAmericasUSD account) between 
the records with missing batch no. in netsuite and the ones in batch 139 and 141 in settlement data 
is the same, they may be related and should be checked.

*/

---- (i) take the orders (with aggregated amount) with missing batch no. from netsuite 

with #missingbatch as (
select 
	MERCHANT_ACCOUNT, 
	BATCH_NUMBER, 
	ORDER_REF, 
	AMOUNT_FOREIGN
from [dbnine].[dbo].[task1_output] 
where MERCHANT_ACCOUNT = 'JetBrainsAmericasUSD'  and BATCH_NUMBER is null
)

---- (ii) then take the orders (with aggregated amount) from settlement data 

, #pg as (
select 
	MERCHANT_ACCOUNT_PG, 
	BATCH_NUMBER_PG, 
	ORDER_REF_PG, 
	GROSS
from [dbnine].[dbo].[task1_output] 
where MERCHANT_ACCOUNT_PG = 'JetBrainsAmericasUSD' 
)

---- (iii) match both dataset 

select *
into #issue1
from #missingbatch a
left join #pg b on 
	a.ORDER_REF = b.ORDER_REF_PG 
	and a.AMOUNT_FOREIGN = b.GROSS;

select 
	BATCH_NUMBER_PG, 
	count(distinct ORDER_REF) as NumOrder, 
	sum(AMOUNT_FOREIGN) as AMOUNT_NS
from #issue1
group by BATCH_NUMBER_PG;

/* 

As the order ref. and amount are fully matched, the netsuite data with missing batch no. 
is indeed related to unmatched settlement in batch 139 and 141.

*/

---- 2.2.2 With batch no., but no data in NetSuite

select 
	MERCHANT_ACCOUNT_PG, 
	BATCH_NUMBER_PG, 
	ORDER_REF_PG, 
	GROSS
from [dbnine].[dbo].[task1_output] 
where ORDER_REF in (
	select distinct ORDER_REF_PG
	from [dbnine].[dbo].[task1_output] 
	where MERCHANT_ACCOUNT_PG = 'JetBrainsGBP' and BATCH_NUMBER_PG = '141')

/*

Now only the records in JetBrainsGBP account with batch 141 not matched
However, no order ref. found in the netsuite data. Further analysis is needed.

*/



---- 2.2.3 With batch no. and data in NetSuite, but the amount doesn't match

select *
from [dbnine].[dbo].[task1_output]
where MERCHANT_ACCOUNT = 'JetBrainsEUR' and BATCH_NUMBER in ('138','139')
order by BATCH_NUMBER;

/* 

The data in bacth 138 & 139 of JetBrainsEUR account are matched, but the amount 
is different (partial matched). 
Since the gross amount from settlement data is much higher in batch 138, this
issue will be checked separately for each batch.

*/

---- (i) check the data from batch 138 first

with #ns_agg as (
select
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF,
	sum(AMOUNT_FOREIGN) as AMOUNT_FOREIGN 
from [dbnine].[dbo].[task1_output_netsuite]
where MERCHANT_ACCOUNT = 'JetBrainsEUR' and BATCH_NUMBER in ('138')
group by
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF
)
, #pg_agg as (
select 
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF,
	sum(GROSS) as GROSS,
	sum(NET) as NET
from [dbnine].[dbo].[task1_output_settlement]
where MERCHANT_ACCOUNT = 'JetBrainsEUR' and BATCH_NUMBER in ('138')
group by
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF
)
select 
	a.MERCHANT_ACCOUNT, 
	a.BATCH_NUMBER,
	a.ORDER_REF,
	a.AMOUNT_FOREIGN,
	b.GROSS, 
	a.AMOUNT_FOREIGN - b.GROSS as Diff,
	b.NET
into #issue3_1
from #ns_agg a
left join #pg_agg b on 
	a.MERCHANT_ACCOUNT = b.MERCHANT_ACCOUNT 
	and a.BATCH_NUMBER = b.BATCH_NUMBER
	and a.ORDER_REF = b.ORDER_REF;

select 
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	sum(AMOUNT_FOREIGN) as AMOUNT_FOREIGN,
	sum(GROSS) as GROSS,
	sum(NET) as NET,
	sum(Diff) as Diff,
	count(distinct ORDER_REF) as NumOrder
from #issue3_1
group by
	MERCHANT_ACCOUNT,
	BATCH_NUMBER;

select distinct ACCOUNTNUMBER from [dbnine].[dbo].[task1_output_netsuite]
where ORDER_REF in (select distinct ORDER_REF from #issue3_1)


/*

The NET sum equals to the difference in both settlement GROSS and netsuite AMOUNT_FOREIGN.
In netsuite only records from account number 548201, and the data from account 315700 (JBCZ: 
Receivables against ADYEN-EUR) are missing. 

*/

---- (ii) now check the data from batch 139

with #ns_agg as (
select 
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF,
	sum(AMOUNT_FOREIGN) as AMOUNT_FOREIGN
from [dbnine].[dbo].[task1_output_netsuite]
where MERCHANT_ACCOUNT = 'JetBrainsEUR' and BATCH_NUMBER in ('139')
group by
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF
)
, #pg_agg as (
select 
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF,
	sum(GROSS) as GROSS,
	sum(case when TYPE = 'Refund' then GROSS end) as GROSS_REFUND
from [dbnine].[dbo].[task1_output_settlement]
where MERCHANT_ACCOUNT = 'JetBrainsEUR' and BATCH_NUMBER in ('139')
group by
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	ORDER_REF
)
select 
	a.MERCHANT_ACCOUNT, 
	a.BATCH_NUMBER,
	a.ORDER_REF,
	b.AMOUNT_FOREIGN,
	a.GROSS, 
	coalesce(b.AMOUNT_FOREIGN,0) - a.GROSS as Diff,
	a.GROSS_REFUND
into #issue3_2
from #pg_agg a
left join #ns_agg b on 
	a.MERCHANT_ACCOUNT = b.MERCHANT_ACCOUNT 
	and a.BATCH_NUMBER = b.BATCH_NUMBER
	and a.ORDER_REF = b.ORDER_REF;


select 
	MERCHANT_ACCOUNT,
	BATCH_NUMBER,
	sum(AMOUNT_FOREIGN) as AMOUNT_FOREIGN,
	sum(GROSS) as GROSS,
	sum(Diff) as Diff,
	sum(GROSS_REFUND) as GROSS_REFUND
from #issue3_2
group by
	MERCHANT_ACCOUNT,
	BATCH_NUMBER;

select * from #issue3_2;

select * 
from [dbnine].[dbo].[netsuite]
where ORDER_REF in (
	select distinct ORDER_REF from #issue3_2
	where AMOUNT_FOREIGN is null);

/*

43 order refund in settlement data is missing in NetSuite.
In addition, 4 orders out of the missing data are settled in batch 138 (not in batch 139), 
thus AMOUNT_FOREIGN is missing in netsuite batch 139 

*/

