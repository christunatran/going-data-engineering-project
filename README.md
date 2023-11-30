# Objective

The task was to build a “Customer Lifetime Value” (CLV) data mart that calculates the average amount a customer has spent with the company since signing up. I built a simplified ELT pipeline, performing data transformation using dbt and leveraging Snowflake as the data warehouse. 

# Steps

### 1. Extract data from S3

- Using AWS CLI,
- Input AWS Access Key, Secret Access Key, default region, and output format
    - Use `us-east-1` as default region
    - Use `json` as output format
- Copy files from S3 to local machine
    
    ```bash
    # configure AWS CLI
    $ aws configure
    
    # copy files
    $ aws s3 cp s3://going-candidate-data/data_engineer1/customers.csv ./customers.csv
    $ aws s3 cp s3://going-candidate-data/data_engineer1/invoices.csv ./invoices.csv
    ```
    

### 2. Load data into Snowflake

- Create a staging area in the Snowflake Console or the `CREATE STAGE` command
    
    ```sql
    -- switch to the right role, database, and schema
    USE ROLE CTRAN_ROLE;
    USE DATABASE CANDIDATE_SANDBOX;
    USE SCHEMA CTRAN;
    
    -- create a stage named my_file_stage
    CREATE STAGE my_file_stage;
    
    -- show stages to confirm
    SHOW STAGES;
    ```
    
- Create the INVOICES and CUSTOMERS tables in Snowflake
    
    ```sql
    CREATE TABLE INVOICES (
        invoice_id INTEGER,
        customer_id INTEGER,
        product_id INTEGER,
        invoice_date DATE,
        amount FLOAT
    );
    
    CREATE TABLE CUSTOMERS (
        customer_id INTEGER,
        signup_date DATE
    );
    ```
    
- Using Python, connect to Snowflake and load the data
    - Run the python script `load_data_into_snowflake.py`:
        ```python
        import snowflake.connector

        # establish a connection to Snowflake
        conn = snowflake.connector.connect(
            account='REDACTED',
            user='REDACTED',
            password='REDACTED',
            database='REDACTED',
            schema='REDACTED',
            role='REDACTED'
        )
        
        # create a cursor object
        cur = conn.cursor()
        
        try:
            # upload invoices.csv file to Snowflake stage
            cur.execute("PUT file:///Users/christinatran/Desktop/going_data_engineer_assessment/invoices.csv @my_file_stage AUTO_COMPRESS=TRUE;")
        
            # copy the staged invoices data into the invoices table in Snowflake
            copy_invoices = """
            COPY INTO invoices 
            FROM @my_file_stage/invoices.csv.gz
            FILE_FORMAT=(TYPE='CSV' FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
            ON_ERROR = 'CONTINUE';
            """
        
            cur.execute(copy_invoices)
        
            # upload customers.csv file to Snowflake stage
            cur.execute("PUT file:///Users/christinatran/Desktop/going_data_engineer_assessment/customers.csv @my_file_stage AUTO_COMPRESS=TRUE;")
        
            # copy the staged customers data into the customers table in Snowflake
            copy_customers = """
            COPY INTO customers
            FROM @my_file_stage/customers.csv.gz
            FILE_FORMAT=(TYPE='CSV' FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
            ON_ERROR = 'CONTINUE';
            """
        
            cur.execute(copy_customers)
        
        finally:
            # close the cursor
            cur.close()
        
        # close the connection
        conn.close()
        ```
  
        ```bash
        python load_data_into_snowflake.py
        ```
        
- Refresh Snowflake objects and see that the data in CTRAN → Tables → CUSTOMERS/INVOICES

### 3. Initialize a new dbt project using dbt cloud

- Start a new project, link Snowflake account using given credentials, and link GitHub account to create a repository of the project deliverables
    - Create github repo called `going-data-engineer-assessment` to connect to dbt cloud
- In dbt cloud IDE, click “Initialize dbt project”

### 4. Generate a new model in dbt called `mart_customer_lifetime_value`

- Required columns: **`customer_id`**, **`signup_date`**, **`lifetime_value`**

```sql
-- mart_customer_lifetime_value.sql
WITH base AS (
  SELECT 
    c.customer_id,
    c.signup_date,
    SUM(i.amount) as total_spent
  FROM customers c
  JOIN invoices i ON c.customer_id = i.customer_id
  GROUP BY 1,2
)
SELECT 
  customer_id,
  signup_date,
  total_spent AS lifetime_value
FROM base
```

- To run:
    
    ```bash
    $ dbt run
    ```
    
    - Any created models persist into Snowflake

### 5. Write 2 tests in dbt for the model you just created

- Configured the tests in `models/schema.yml`
    - Uniqueness test for `customer_id` column in the mart
    - Not-null test for `lifetime_value` column in the mart

```yaml
# models/schema.yml
models:
  - name: mart_customer_lifetime_value
    tests:
      - unique:
          column_name: customer_id
      - not_null:
          column_name: lifetime_value
```

- To test:
    
    ```bash
    $ dbt test
    ```
    

### 6. Create and execute a job within dbt Cloud that creates a new table and tests the data

- In dbt cloud: Deploy → Environment → Create New Job
- Create a job called “Create CLV Data Mart and Test Data”
- Running the job: manual trigger using the “Run Now’ button
