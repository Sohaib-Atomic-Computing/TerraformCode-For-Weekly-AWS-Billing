import boto3
from datetime import datetime, timedelta
import json
import urllib3
import os
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    # Initialize the AWS Cost Explorer client
    ce_client = boto3.client('ce')
    http = urllib3.PoolManager()

    # Retrieve the account name from environment variable
    account_name = os.getenv('ACCOUNT_NAME', 'Default Account Name')
    slack_webhook_url = os.getenv('SLACK_WEBHOOK_URL')
    
    # Calculate the start and end dates for the past week
    end_date = datetime.utcnow().date() + timedelta(days=1)
    start_date = end_date - timedelta(days=7)

    # Define the time period
    time_period = {
        'Start': start_date.strftime('%Y-%m-%d'),
        'End': end_date.strftime('%Y-%m-%d')
    }
    
    print(time_period)

    # Get the weekly billing details
    response = ce_client.get_cost_and_usage(
        TimePeriod=time_period,
        Granularity='DAILY',
        Metrics=['UnblendedCost'],
        # Filter={
        #     'Dimensions': {
        #         'Key': 'RECORD_TYPE',
        #         'Values': ['Credit'],
        #         'MatchOptions': ['EQUALS']
        #     }
        # },
        GroupBy=[
            {
                'Type': 'DIMENSION',
                'Key': 'SERVICE'
            }
        ]
    )
    
    print(response)
    
    api_result = response["ResultsByTime"]
    time_range = 7
    weekly_cost = 0.0
    service_costs = {}  # Dictionary to store total cost for each service over the week
    for i in range(time_range):
        for group in api_result[i]["Groups"]:
            service = group["Keys"][0]
            daily_cost_per_service = abs(round(float(group["Metrics"]["UnblendedCost"]["Amount"]), 2))
            
            # Accumulate the daily cost for each service
            if service in service_costs:
                service_costs[service] += daily_cost_per_service
            else:
                service_costs[service] = daily_cost_per_service
                
            # Accumulate the weekly cost
            weekly_cost += daily_cost_per_service

    # Round up weekly billing to two decimal points
    weekly_cost = round(weekly_cost, 2)

    # Print weekly billing
    print(f"Weekly billing: ${weekly_cost}")

    # Format the time period
    time_period_str = f"Billing Time period: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}"

    # Format the message for Slack notification as a code block for better alignment
    message = f"*Account Name: {account_name}*\n\n" \
              f"```\n" \
              f"{time_period_str}\n\n" \
              f"{'-'*78}\n" \
              f"| {'Service':<40} | {'Weekly Cost':<10} |\n" \
              f"{'-'*78}\n"
    
    # Append service costs to the message
    for service, total_cost in service_costs.items():
        total_cost = abs(round(total_cost, 2))
        message += f"| {service:<40} | ${total_cost:<10} |\n"
    
    message += f"{'-'*78}\n" \
               f"| {'Total Weekly Billing':<40} | ${weekly_cost:<10} |\n" \
               f"{'-'*78}\n" \
               f"```\n"

    # Send the message to Slack webhook
    new_event_data = {"text": message}
    print("New-Event-Data", new_event_data)
    
    r = http.request("POST", 
                     slack_webhook_url, 
                     body=json.dumps(new_event_data), 
                     headers={"Content-Type": "application/json"}
                    )

    # print(r.status)  

    return {
        'statusCode': 200,
        'body': json.dumps('Weekly billing details processed successfully')
    }
