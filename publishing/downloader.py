import codecs
from datetime import timedelta, date
import os
import shutil
from time import sleep, mktime
from urllib.error import URLError, HTTPError
import urllib.request
import uuid
import xml.etree.ElementTree as ET

from pmetro.file_utils import unzip_file, find_file_by_extension
from pmetro.ini_files import deserialize_ini, get_ini_attr
from publishing.catalog import MapCatalog, load_catalog

DOWNLOAD_MAP_MAX_RETRIES = 5

IGNORE_MAP_LIST = [
    'Moscow3d.zip',
    'MoscowGrd.zip',
    'Moscow_skor.zip',
    'Moscow_pix.zip',
    'MoscowHistory.zip',
    'Moscow_f.zip',
    'Moscow_old.zip',
    'PeterburgOld.zip'
]

MAP_NAME_FIX = {
    'Athenas': 'Athens',
    'Bonn-Koln': 'Koln',
    'Kolkata(Calcutta)': 'Kolkata',
    'Minneapolis - St.Paul': 'Minneapolis',
    'Мiнск': 'Minsk'
}


class MapDownloader(object):
    def __init__(self, service_url, pmetro_path, cache_path, temp_path, logger, geonames_provider):

        self.__download_chunk_size = 16 * 1024
        self.__service_url = service_url
        self.__pmetro_path = pmetro_path
        self.__local_files = True  # todo check actual downloader logic (autoupdate is not uploaded until end of action)
        self.__cache_path = cache_path
        self.__index_path = os.path.join(cache_path, 'index.json')
        self.__logger = logger
        self.__temp_path = temp_path
        self.__geonames_provider = geonames_provider

    def refresh(self, force=False):
        remote_maps = list(self.__download_map_index())
        if force:
            old_catalog = MapCatalog()
        else:
            old_catalog = load_catalog(self.__index_path)

        cache_catalog = MapCatalog()
        for new_map in remote_maps:
            old_map = old_catalog.find_by_file(new_map['file'])
            if old_map is None or old_map['timestamp'] < new_map['timestamp'] or old_map['size'] != new_map['size']:

                city_name = new_map['city']
                country_name = new_map['country']

                city_info = self.__geonames_provider.find_city(city_name, country_name)
                if city_info is None:
                    self.__logger.warning('Not found %s, [%s]/[%s], skipped' % (new_map['file'], city_name, country_name))
                    continue

                self.__logger.debug('Recognised %s,%s,%s in [%s]/[%s]' % (
                    city_info.geoname_id, city_info.name, city_info.country, city_name, country_name))

                downloading_map = {
                    'city_id': city_info.geoname_id,
                    'file': new_map['file'],
                    'size': new_map['size'],
                    'timestamp': new_map['timestamp'],
                    'map_id': None
                }

                self.__download_map(downloading_map)
                cache_catalog.add_map(downloading_map)
            else:
                self.__logger.info('Map [%s] already downloaded.' % new_map['file'])
                cache_catalog.add_map(old_map)

        for old_map in old_catalog.maps:
            if not any([m for m in remote_maps if m['file'] == old_map['file']]):
                os.remove(os.path.join(self.__cache_path, old_map['file']))
                self.__logger.warning('Map [%s] removed as obsolete.' % old_map['file'])

        cache_catalog.save(self.__index_path)

    def __download_map_index(self):

        try:
            if not self.__local_files:
                xml_url = self.__service_url + 'Files.xml'
                xml_maps = urllib.request.urlopen(xml_url).read().decode('windows-1251')
        except HTTPError as e:
            if e.code != 404:
                raise
            self.__local_files = True
        if self.__local_files:
            xml_local_file = os.path.join(self.__pmetro_path, "Files.xml")
            xml_maps = open(xml_local_file, "rb").read().decode('windows-1251')


        with codecs.open(os.path.join(self.__cache_path, "Files.xml"), 'w', 'utf-8') as f:
            f.write(xml_maps)

        for el in ET.fromstring(xml_maps):
            file_name = el.find('Zip').attrib['Name']
            if file_name in IGNORE_MAP_LIST:
                self.__logger.info('Ignored [%s].' % file_name)
                continue

            city_name = el.find('City').attrib['CityName']
            country_name = el.find('City').attrib['Country']
            if country_name == ' Программа' or city_name == '':
                self.__logger.info('Skipped %s, [%s]/[%s]' % (file_name, city_name, country_name))
                continue
            if city_name in MAP_NAME_FIX:
                city_name = MAP_NAME_FIX[city_name]

            size = int(el.find('Zip').attrib['Size'])
            timestamp = mktime((date(1899, 12, 30) + timedelta(days=int(el.find('Zip').attrib['Date']))).timetuple())
            yield {'file': file_name, 'size': size, 'timestamp': timestamp, 'city': city_name, 'country': country_name}

    def __download_map(self, map_item):
        logger_comment = ''
        map_file = map_item['file']
        tmp_path = os.path.join(self.__cache_path, map_file + '.download')
        map_path = os.path.join(self.__cache_path, map_file)

        retry = 0
        map_url = self.__service_url + map_file
        while retry < DOWNLOAD_MAP_MAX_RETRIES:
            retry += 1

            if os.path.isfile(tmp_path):
                os.remove(tmp_path)
            if self.__local_files:
                local_path = os.path.join(self.__pmetro_path, map_file)
                shutil.copyfile(local_path, tmp_path)
                logger_comment = " (bootstrap)"
            else:
                try:
                    urllib.request.urlretrieve(map_url, tmp_path)
                except URLError:
                    self.__logger.warning('Map [%s] download from url %s error, wait and retry.' % (map_file, map_url))
                    sleep(0.5)
                    continue

            self.__fill_map_info(tmp_path, map_item)

            if os.path.isfile(map_path):
                os.remove(map_path)

            os.rename(tmp_path, map_path)
            self.__logger.info(f'Downloaded{logger_comment} [{map_file}]')
            return
        raise IOError('Max retries for downloading file [%s] reached. Terminate.' % map_file)

    def __fill_map_info(self, map_file, map_item):
        self.__logger.info('Extract map info from [%s]' % map_file)
        temp_folder = os.path.join(self.__temp_path, uuid.uuid1().hex)
        try:
            unzip_file(map_file, temp_folder)
            pmz_file = find_file_by_extension(temp_folder, '.pmz')
            map_folder = pmz_file[0:-4]
            unzip_file(pmz_file, map_folder)

            self.__extract_map_id(map_folder, map_item)

        finally:
            shutil.rmtree(temp_folder)

    def __extract_map_id(self, map_folder, map_item):
        ini = deserialize_ini(find_file_by_extension(map_folder, '.cty'))
        name = get_ini_attr(ini, 'Options', 'Name')

        if name is None:
            name = uuid.uuid1().hex
            self.__logger.warning('Empty NAME map property in file \'%s\', used UID %s' % (ini['__FILE_NAME__'], name))

        map_item['map_id'] = name
