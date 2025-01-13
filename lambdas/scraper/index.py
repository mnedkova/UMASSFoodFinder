from bs4 import BeautifulSoup
import datetime
import json
import boto3
import requests
from html.parser import HTMLParser
from elasticsearch import Elasticsearch


class Parser(HTMLParser):
    def __init__(self):
        HTMLParser.__init__(self)
        self.current_entree = None
        self.entrees = []
    
    def handle_starttag(self, tag, attrs):
        if (tag == 'a'):
            self.current_entree = {}
            for elem in attrs:
                self.current_entree[elem[0]] = elem[1]
                
            
    def handle_endtag(self, tag):
        if (tag== 'a'):
            self.current_entree = None
    
    def handle_data(self, data):
        if (self.current_entree != None):
            self.current_entree['name'] = data
            self.entrees.append(self.current_entree)
            self.current_entree = None
    
def extractDoc(date, hall_id, hall_name, json_doc):
    doc = {
        'id': f'{date}-{hall_name}',
        'date': date.isoformat(),
        'hall': hall_name,
        'hall_id': hall_id,
    }
    
    entrees = []
    parser = Parser()
    
    for meal in json_doc:
        for category in json_doc[meal]:
            parser.feed(json_doc[meal][category])
            for entree in parser.entrees:
                entree['meal'] = meal
                entree['category'] = category
            entrees.extend(parser.entrees)
            parser.entrees = []
        doc['entrees'] = entrees
    return doc
            
def lambda_handler(event, context):
    #Bucket Access
    s3 = boto3.resource("s3")
    bucket = s3.Bucket("umassdininginfo")
    
    #Secrets Access
    secrets_manager = boto3.client('secretsmanager')
    secrets = secrets_manager.get_secret_value(SecretId="prod/foodfinder")
    secret_dict = json.loads(secrets["SecretString"])
    elastic_user = secret_dict["ES_USER"]
    elastic_password = secret_dict["ES_PASSWORD"]
    elastic_search_client = client = Elasticsearch("https://elasticsearch.nedkova.us", http_auth=(elastic_user, elastic_password))
    
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
            
            #Adds original files to the S3 umassdininginfo archive bucket
            
            try: 
                #Adds original files to the S3 umassdininginfo archive bucket
                json_response = link.json()
                text_response = link.text
                text_object = text_response.encode("utf-8")
                object_name = f'archive/{current_day}/{location_name}.json'
                bucket.put_object(Key=object_name, Body=text_object)
                
                #Scrapes specific key items
                doc = extractDoc(current_day, location_id, location_name, json_response)
                doc_string = json.dumps(doc).encode("utf-8")
                doc_location=f'data/{current_day}/{location_name}.json'
                bucket.put_object(Key=doc_location, Body=doc_string)
                
                resp = client.index(index="foodfinder", id=doc["id"], body=doc)
                print(resp["result"])

                
            except ValueError:
                print(f'Error... no json response')
                continue
            
if __name__ == "__main__":
    event = []
    context = []
    lambda_handler(event, context) 
        
    
    