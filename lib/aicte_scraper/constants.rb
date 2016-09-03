class AicteScraper
  class Constants
    COLLEGES_URL = -'http://www.aicte-india.org/dashboard/pages/php/approvedinstituteserver.php?method=fetchdata&year=2016-2017&program=1&level=1&institutiontype=1&Women=1&Minority=1&state=%{state}&course='

    COURSE_DETAILS_URL = -'http://www.aicte-india.org/dashboard/pages/approved.php?aicteid=%{aicte_id}&course=&year=2016-2017'

    # Extracted from their form. The value 'Orissa' has been removed since it returns no results, and seems to have been replaced by 'Odisha' - the state's new official name.
    STATES = [
      'Andaman and Nicobar Islands',
      'Andhra Pradesh',
      'Arunachal Pradesh',
      'Assam',
      'Bihar',
      'Chandigarh',
      'Chhattisgarh',
      'Dadra and Nagar Haveli',
      'Daman and Diu',
      'Delhi',
      'Goa',
      'Gujarat',
      'Haryana',
      'Himachal Pradesh',
      'Jammu and Kashmir',
      'Jharkhand',
      'Karnataka',
      'Kerala',
      'Madhya Pradesh',
      'Maharashtra',
      'Manipur',
      'Meghalaya',
      'Mizoram',
      'Nagaland',
      'Odisha',
      'Puducherry',
      'Punjab',
      'Rajasthan',
      'Sikkim',
      'Tamil Nadu',
      'Telangana',
      'Tripura',
      'Uttar Pradesh',
      'Uttarakhand',
      'West Bengal'
    ].freeze
  end
end
