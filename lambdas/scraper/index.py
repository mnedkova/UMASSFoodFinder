from bs4 import BeautifulSoup
import datetime
import json
import boto3
import requests

# def lambda_handler(event, context):
#    message = 'Hello {} !'.format(event['key1'])
#    return {
#        'message' : message
#    }


#Base_URL: https://umassdining.com/foodpro-menu-ajax?tid={id}&date="{date}"

def lambda_handler(event, context):
    tid = {
        1: "Worcester",
        2: "Franklin",
        3: "Hampshire",
        4: "Berkshire",  
    }
    
    
    # For loop iterates through each dining hall for each specified day to form desired link
    for location_id, location_name in tid.items():
        base_url = f'https://umassdining.com/foodpro-menu-ajax?tid={location_id}&date='
        
        
        MAX_DAYS = 14
        current_day = datetime.date.today()
        print(current_day)
        # iterates through each day
        for options in range(MAX_DAYS):
            current_day = current_day + datetime.timedelta(days=1)
            print(current_day)
            
            
        
        
    
    