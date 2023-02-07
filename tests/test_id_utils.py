from idutils import (
    detect_identifier_schemes,
    normalize_doi,
    normalize_arxiv,
    normalize_pmid,
    normalize_isbn,
    normalize_ror,
    normalize_orcid,
)

from iga.id_utils import *


sample_ids = [
    ('arXiv:2012.13117v1'            , 'arxiv' ),
    ('10.48550/arXiv.2012.13117'     , 'doi'   ),
    ('PMC4908318'                    , 'pmcid' ),
    ('26861819'                      , 'pmid'  ),
    ('10.1093/bioinformatics/btw056' , 'doi'   ),
    ('10.1007/978-1-4939-3283-2_19'  , 'doi'   ),
    ('10.1103/PhysRevD.90.124021'    , 'doi'   ),
    ('26677194'                      , 'pmid'  ),
    ('978-0982477373'                , 'isbn'  ),
    ('9780898714128'                 , 'isbn'  ),
    ('9781979381208'                 , 'isbn'  ),
]


def test_contains_pmcid():
    for _id, scheme in sample_ids:
        if scheme == 'pmcid':
            assert contains_pmcid(_id)


def test_normalize_pmcid():
    assert normalize_pmcid('pmc4908318') == 'PMC4908318'


def test_recognized_scheme():
    for _id, scheme in sample_ids:
        assert recognized_scheme(_id) == scheme


sample_unnormalized_ids = [
    ('http://orcid.org/0000-0001-9105-5960'   , '0000-0001-9105-5960'),
    ('https://doi.org/10.5281/zenodo.1095472' , '10.5281/zenodo.1095472'),
    ('https://ror.org/027m9bs27'              , '027m9bs27'),
    ('10.1088/0264-9381/26/22/225003'         , '10.1088/0264-9381/26/22/225003'),
    ('PMCID; PMC4908318'                      , ''),
    ('PMC4908318'                             , 'PMC4908318'),
]


def test_detected_id():
    for _id, scheme in sample_unnormalized_ids:
        assert detected_id(_id) == scheme
