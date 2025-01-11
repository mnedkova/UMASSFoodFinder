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
    
    s3 = boto3.resource("s3")
    bucket = s3.Bucket("umassdininginfo")
    
    
    tid = {
        1: "Worcester",
        2: "Franklin",
        3: "Hampshire",
        4: "Berkshire",  
    }
    
    # For loop iterates through each dining hall for each specified day to form desired link
    for location_id, location_name in tid.items():
        MAX_DAYS = 14
        today = datetime.date.today()
        # iterates through each day
        for options in range(MAX_DAYS):
            current_day = today + datetime.timedelta(days=options)
            print(current_day)
            formatted_day = current_day.strftime('%m/%d/%Y')
            url = f'https://umassdining.com/foodpro-menu-ajax?tid={location_id}&date={formatted_day}'
            link = requests.get(url)
            
            if link.status_code != 200:
                print(f'Error... {url} returned {link.status_code}')
                continue
            
            try: 
                json_response = link.json()
                text_response = link.text()
                text_object = text_response.encode("utf-8")
                object_name = f'archive/{current_day}/{location_id}.json'
                bucket.put_object(Key=object_name, Body=text_object)
            except ValueError:
                print(f'Error... no json response')
                continue
            

            
            
            
            
            
            
if __name__ == "__main__":
    event = []
    context = []
    lambda_handler(event, context) 
        
    
    