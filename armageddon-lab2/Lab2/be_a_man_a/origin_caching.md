Why origin-driven caching is safer for APIs
because the origin remains the source of what is cacheable, for how long, and under which guidelines.  Along with it reducing accidental caching sensitive data(which is very important to companies), it keeps behaviors consistent across all layers(browser, edge, gateway, and app level), and for security and compliance. 

When would you still disable caching entirely
You would disable it when the APIs are never suppose to be stored or reused. Other reasons can be if it would violate privacy, personalized data(medical, financial, etc.) or compliance. So anything that could be labeled as sensitive data caching should be disabled. 

