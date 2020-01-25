###############################################################################
# $Id: ONKYOdb.pm 14012 2017-04-17 13:09:41Z loredo $
package main;
sub ONKYOdb_Initialize() { }

package ONKYOdb;
use strict;
use warnings;

# ----------------Human Readable command mapping table-----------------------
my $ONKYO_cmds_hr = {
    'dock' => {
        'command-for-docking-station-via-ri' => 'CDS'
    },
    '1' => {
        '12v-trigger-a'                 => 'TGA',
        '12v-trigger-b'                 => 'TGB',
        '12v-trigger-c'                 => 'TGC',
        'audio-information'             => 'IFA',
        'audio-input'                   => 'SLA',
        'audyssey-2eq-multeq-multeq-xt' => 'ADY',
        'audyssey-dynamic-eq'           => 'ADQ',
        'audyssey-dynamic-volume'       => 'ADV',
        'cd-player'                     => 'CCD',
        'cd-recorder'                   => 'CCR',
        'center-temporary-level'        => 'CTL',
        'cinema-filter'                 => 'RAS',
        'dab-display-info'              => 'UDD',
        'dab-preset'                    => 'UPR',
        'dab-station-name'              => 'UDS',
        'dat-recorder'                  => 'CDT',
        'dimmer-level'                  => 'DIM',
        'display-mode'                  => 'DIF',
        'dolby-volume'                  => 'DVL',
        'dvd-player'                    => 'CDV',
        'graphics-equalizer'            => 'CEQ',
        'hd-radio-artist-name-info'     => 'UHA',
        'hd-radio-blend-mode'           => 'UHB',
        'hd-radio-channel-name-info'    => 'UHC',
        'hd-radio-channel-program'      => 'UHP',
        'hd-radio-detail-info'          => 'UHD',
        'hd-radio-title-info'           => 'UHT',
        'hd-radio-tuner-status'         => 'UHS',
        'hdmi-audio-out'                => 'HAO',
        'hdmi-output'                   => 'HDO',
        'hdmi-cec'                      => 'CEC',
        'input'                         => 'SLI',
        'internet-radio-preset'         => 'NPR',
        'ipod-album-name-info'          => 'IAL',
        'ipod-artist-name-info'         => 'IAT',
        'ipod-list-info'                => 'ILS',
        'ipod-mode-change'              => 'IMD',
        'ipod-play-status'              => 'IST',
        'ipod-time-info'                => 'ITM',
        'ipod-title-name'               => 'ITI',
        'ipod-track-info'               => 'ITR',
        'isf-mode'                      => 'ISF',
        'late-night'                    => 'LTN',
        'listening-mode'                => 'LMD',
        'md-recorder'                   => 'CMD',
        'memory-setup'                  => 'MEM',
        'monitor-out-resolution'        => 'RES',
        'music-optimizer'               => 'MOT',
        'mute'                          => 'AMT',
        'net-keyboard'                  => 'NKY',
        'net-popup-message'             => 'NPU',
        'net-receiver-information'      => 'NRI',
        'net-service'                   => 'NSV',
        'network-standby'               => 'NSB',
        'net-usb-album-name-info'       => 'NAL',
        'net-usb-artist-name-info'      => 'NAT',
        'net-usb-jacket-art'            => 'NJA',
        'net-usb-list-info'             => 'NLS',
        'net-usb-list-info-xml'         => 'NLA',
        'net-usb-list-title-info'       => 'NLT',
        'net-usb-device-status'         => 'NDS',
        'net-usb-menu-status'           => 'NMS',
        'net-usb-play-status'           => 'NST',
        'net-usb-time-info'             => 'NTM',
        'net-usb-time-seek'             => 'NTS',
        'net-usb-title-name'            => 'NTI',
        'net-usb-track-info'            => 'NTR',
        'net-usb'                       => 'NTC',
        'preset'                        => 'PRS',
        'preset-memory'                 => 'PRM',
        'pty-scan'                      => 'PTS',
        'rds-information'               => 'RDS',
        'record-output'                 => 'SLR',
        'setup'                         => 'OSD',
        'sirius-artist-name-info'       => 'SAT',
        'sirius-category'               => 'SCT',
        'sirius-channel-name-info'      => 'SCN',
        'sirius-channel-number'         => 'SCH',
        'sirius-parental-lock'          => 'SLK',
        'sirius-title-info'             => 'STI',
        'sleep'                         => 'SLP',
        'speaker-a'                     => 'SPA',
        'speaker-b'                     => 'SPB',
        'speaker-layout'                => 'SPL',
        'speaker-level-calibration'     => 'SLC',
        'subwoofer-temporary-level'     => 'SWL',
        'subwoofer2-temporary-level'    => 'SW2',
        'phase-matching-bass'           => 'PMB',
        'power'                         => 'PWR',
        'tape1-a'                       => 'CT1',
        'tape2-b'                       => 'CT2',
        'tone-center'                   => 'TCT',
        'tone-front'                    => 'TFR',
        'tone-front-high'               => 'TFH',
        'tone-front-wide'               => 'TFW',
        'tone-subwoofer'                => 'TSW',
        'tone-surround'                 => 'TSR',
        'tone-surround-back'            => 'TSB',
        'tp-scan'                       => 'TPS',
        'tunerFrequency'                => 'TUN',
        'universal-port'                => 'CPT',
        'video-information'             => 'IFV',
        'video-output'                  => 'VOS',
        'video-picture-mode'            => 'VPM',
        'video-wide-mode'               => 'VWM',
        'volume'                        => 'MVL',
        'xm-artist-name-info'           => 'XAT',
        'xm-category'                   => 'XCT',
        'xm-channel-name-info'          => 'XCN',
        'xm-channel-number'             => 'XCH',
        'xm-title-info'                 => 'XTI'
    },
    '2' => {
        'balance'               => 'ZBL',
        'internet-radio-preset' => 'NPZ',
        'late-night'            => 'LTZ',
        'listening-mode'        => 'LMZ',
        'mute'                  => 'ZMT',
        'net-usb-z'             => 'NTZ',
        'power'                 => 'ZPW',
        'preset'                => 'PRZ',
        're-eq-academy-filter'  => 'RAZ',
        'input'                 => 'SLZ',
        'tone'                  => 'ZTN',
        'tunerFrequency'        => 'TUZ',
        'volume'                => 'ZVL'
    },
    '3' => {
        'balance'               => 'BL3',
        'internet-radio-preset' => 'NP3',
        'mute'                  => 'MT3',
        'net-usb-z'             => 'NT3',
        'power'                 => 'PW3',
        'preset'                => 'PR3',
        'input'                 => 'SL3',
        'tone'                  => 'TN3',
        'tunerFrequency'        => 'TU3',
        'volume'                => 'VL3'
    },
    '4' => {
        'internet-radio-preset' => 'NP4',
        'mute'                  => 'MT4',
        'net-usb-z'             => 'NT4',
        'power'                 => 'PW4',
        'preset'                => 'PR4',
        'input'                 => 'SL4',
        'tunerFrequency'        => 'TU4',
        'volume'                => 'VL4'
    }
};

# ----------------Human Readable value mapping table-----------------------
my $ONKYO_values_hr = {
    'dock' => {
        'CDS' => {
            'album'   => 'ALBUM-',
            'blight'  => 'BLIGHT',
            'chapt'   => 'CHAPT-',
            'down'    => 'DOWN',
            'enter'   => 'ENTER',
            'ff'      => 'FF',
            'men'     => 'MENU',
            'mute'    => 'MUTE',
            'off'     => 'PWROFF',
            'on'      => 'PWRON',
            'pause'   => 'PAUSE',
            'plist'   => 'PLIST-',
            'ply-pa'  => 'PLY/PAU',
            'ply-res' => 'PLY/RES',
            'random'  => 'RANDOM',
            'repeat'  => 'REPEAT',
            'rew'     => 'REW',
            'skip-f'  => 'SKIP.F',
            'skip-r'  => 'SKIP.R',
            'stop'    => 'STOP',
            'up'      => 'UP'
        }
    },
    '1' => {
        'ADQ' => {
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'ADV' => {
            'heavy'  => '03',
            'light'  => '01',
            'medium' => '02',
            'off'    => '00',
            'query'  => 'QSTN',
            'up'     => 'UP'
        },
        'ADY' => {
            'movie' => '01',
            'music' => '02',
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'AMT' => {
            'off'    => '00',
            'on'     => '01',
            'query'  => 'QSTN',
            'toggle' => 'TG'
        },
        'CCD' => {
            '0'      => '0',
            '1'      => '1',
            '10'     => '+10',
            '2'      => '2',
            '3'      => '3',
            '4'      => '4',
            '5'      => '5',
            '6'      => '6',
            '7'      => '7',
            '8'      => '8',
            '9'      => '9',
            'clear'  => 'CLEAR',
            'd-mode' => 'D.MODE',
            'd-skip' => 'D.SKIP',
            'disc-f' => 'DISC.F',
            'disc-r' => 'DISC.R',
            'disc1'  => 'DISC1',
            'disc2'  => 'DISC2',
            'disc3'  => 'DISC3',
            'disc4'  => 'DISC4',
            'disc5'  => 'DISC5',
            'disc6'  => 'DISC6',
            'disp'   => 'DISP',
            'ff'     => 'FF',
            'memory' => 'MEMORY',
            'op-cl'  => 'OP/CL',
            'pause'  => 'PAUSE',
            'play'   => 'PLAY',
            'pon'    => 'PON',
            'power'  => 'POWER',
            'random' => 'RANDOM',
            'repeat' => 'REPEAT',
            'rew'    => 'REW',
            'skip-f' => 'SKIP.F',
            'skip-r' => 'SKIP.R',
            'stby'   => 'STBY',
            'stop'   => 'STOP',
            'track'  => 'TRACK'
        },
        'CCR' => {
            '1'      => '1',
            '10-0'   => '10/0',
            '2'      => '2',
            '3'      => '3',
            '4'      => '4',
            '5'      => '5',
            '6'      => '6',
            '7'      => '7',
            '8'      => '8',
            '9'      => '9',
            'clear'  => 'CLEAR',
            'disp'   => 'DISP',
            'ff'     => 'FF',
            'memory' => 'MEMORY',
            'op-cl'  => 'OP/CL',
            'p-mode' => 'P.MODE',
            'pause'  => 'PAUSE',
            'play'   => 'PLAY',
            'power'  => 'POWER',
            'random' => 'RANDOM',
            'rec'    => 'REC',
            'repeat' => 'REPEAT',
            'rew'    => 'REW',
            'scroll' => 'SCROLL',
            'skip-f' => 'SKIP.F',
            'skip-r' => 'SKIP.R',
            'stby'   => 'STBY',
            'stop'   => 'STOP'
        },
        'CDT' => {
            'ff'     => 'FF',
            'play'   => 'PLAY',
            'rc-pa'  => 'RC/PAU',
            'rew'    => 'REW',
            'skip-f' => 'SKIP.F',
            'skip-r' => 'SKIP.R',
            'stop'   => 'STOP'
        },
        'CDV' => {
            '0'          => '0',
            '1'          => '1',
            '10'         => '10',
            '2'          => '2',
            '3'          => '3',
            '4'          => '4',
            '5'          => '5',
            '6'          => '6',
            '7'          => '7',
            '8'          => '8',
            '9'          => '9',
            'abr'        => 'ABR',
            'angle'      => 'ANGLE',
            'asctg'      => 'ASCTG',
            'audio'      => 'AUDIO',
            'cdpcd'      => 'CDPCD',
            'clear'      => 'CLEAR',
            'conmem'     => 'CONMEM',
            'disc-f'     => 'DISC.F',
            'disc-r'     => 'DISC.R',
            'disc1'      => 'DISC1',
            'disc2'      => 'DISC2',
            'disc3'      => 'DISC3',
            'disc4'      => 'DISC4',
            'disc5'      => 'DISC5',
            'disc6'      => 'DISC6',
            'disp'       => 'DISP',
            'down'       => 'DOWN',
            'enter'      => 'ENTER',
            'ff'         => 'FF',
            'folddn'     => 'FOLDDN',
            'foldup'     => 'FOLDUP',
            'funmem'     => 'FUNMEM',
            'init'       => 'INIT',
            'lastplay'   => 'LASTPLAY',
            'left'       => 'LEFT',
            'memory'     => 'MEMORY',
            'men'        => 'MENU',
            'mspdn'      => 'MSPDN',
            'mspup'      => 'MSPUP',
            'op-cl'      => 'OP/CL',
            'p-mode'     => 'P.MODE',
            'pause'      => 'PAUSE',
            'pct'        => 'PCT',
            'play'       => 'PLAY',
            'power'      => 'POWER',
            'progre'     => 'PROGRE',
            'pwroff'     => 'PWROFF',
            'pwron'      => 'PWRON',
            'random'     => 'RANDOM',
            'repeat'     => 'REPEAT',
            'return'     => 'RETURN',
            'rew'        => 'REW',
            'right'      => 'RIGHT',
            'rsctg'      => 'RSCTG',
            'search'     => 'SEARCH',
            'setup'      => 'SETUP',
            'skip-f'     => 'SKIP.F',
            'skip-r'     => 'SKIP.R',
            'slow-f'     => 'SLOW.F',
            'slow-r'     => 'SLOW.R',
            'step-f'     => 'STEP.F',
            'step-r'     => 'STEP.R',
            'stop'       => 'STOP',
            'subtitle'   => 'SUBTITLE',
            'subton-off' => 'SUBTON/OFF',
            'topmen'     => 'TOPMENU',
            'up'         => 'UP',
            'vdoff'      => 'VDOFF',
            'zoomdn'     => 'ZOOMDN',
            'zoomtg'     => 'ZOOMTG',
            'zoomup'     => 'ZOOMUP'
        },
        'CEC' => {
            'off'   => '00',
            'on'    => '01',
            'up'    => 'UP',
            'query' => 'QSTN',
        },
        'CEQ' => {
            'power'  => 'POWER',
            'preset' => 'PRESET'
        },
        'CMD' => {
            '1'      => '1',
            '10-0'   => '10/0',
            '2'      => '2',
            '3'      => '3',
            '4'      => '4',
            '5'      => '5',
            '6'      => '6',
            '7'      => '7',
            '8'      => '8',
            '9'      => '9',
            'clear'  => 'CLEAR',
            'disp'   => 'DISP',
            'eject'  => 'EJECT',
            'enter'  => 'ENTER',
            'ff'     => 'FF',
            'group'  => 'GROUP',
            'm-scan' => 'M.SCAN',
            'memory' => 'MEMORY',
            'name'   => 'NAME',
            'p-mode' => 'P.MODE',
            'pause'  => 'PAUSE',
            'play'   => 'PLAY',
            'power'  => 'POWER',
            'random' => 'RANDOM',
            'rec'    => 'REC',
            'repeat' => 'REPEAT',
            'rew'    => 'REW',
            'scroll' => 'SCROLL',
            'skip-f' => 'SKIP.F',
            'skip-r' => 'SKIP.R',
            'stby'   => 'STBY',
            'stop'   => 'STOP'
        },
        'CPT' => {
            '0'      => '0',
            '1'      => '1',
            '10'     => '10',
            '2'      => '2',
            '3'      => '3',
            '4'      => '4',
            '5'      => '5',
            '6'      => '6',
            '7'      => '7',
            '8'      => '8',
            '9'      => '9',
            'disp'   => 'DISP',
            'down'   => 'DOWN',
            'enter'  => 'ENTER',
            'ff'     => 'FF',
            'left'   => 'LEFT',
            'mode'   => 'MODE',
            'pause'  => 'PAUSE',
            'play'   => 'PLAY',
            'skip-f' => 'SKIP.F',
            'skip-r' => 'SKIP.R',
            'stop'   => 'STOP',
            'up'     => 'UP'
        },
        'CT1' => {
            'ff'     => 'FF',
            'play-f' => 'PLAY.F',
            'play-r' => 'PLAY.R',
            'rc-pa'  => 'RC/PAU',
            'rew'    => 'REW',
            'stop'   => 'STOP'
        },
        'CT2' => {
            'ff'     => 'FF',
            'op-cl'  => 'OP/CL',
            'play-f' => 'PLAY.F',
            'play-r' => 'PLAY.R',
            'rc-pa'  => 'RC/PAU',
            'rec'    => 'REC',
            'rew'    => 'REW',
            'skip-f' => 'SKIP.F',
            'skip-r' => 'SKIP.R',
            'stop'   => 'STOP'
        },
        'CTL' => {
            'down'               => 'DOWN',
            'query'              => 'QSTN',
            'up'                 => 'UP',
            'xrange(-12, 0, 12)' => '(-12, 0, 12)'
        },
        'DIF' => {
            '02'        => '02',
            '03'        => '03',
            'query'     => 'QSTN',
            'listening' => '01',
            'volume'    => '00',
            'toggle'    => 'TG'
        },
        'DIM' => {
            'bright'         => '00',
            'bright-led-off' => '08',
            'dark'           => '02',
            'dim'            => 'DIM',
            'query'          => 'QSTN',
            'shut-off'       => '03'
        },
        'DVL' => {
            'high'  => '03',
            'low'   => '01',
            'mid'   => '02',
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'HAO' => {
            'auto'  => '02',
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'HAT' => {
            'query' => 'QSTN'
        },
        'HBL' => {
            'analog' => '01',
            'auto'   => '00',
            'query'  => 'QSTN'
        },
        'HCN' => {
            'query' => 'QSTN'
        },
        'HDO' => {
            'analog'  => '00',
            'both'    => '05',
            'no'      => '00',
            'out'     => '01',
            'out-sub' => '02',
            'query'   => 'QSTN',
            'sub'     => '02',
            'up'      => 'UP',
            'yes'     => '01'
        },
        'HDS' => {
            'query' => 'QSTN'
        },
        'HPR' => {
            'query'        => 'QSTN',
            'xrange(1, 8)' => '(1, 8)'
        },
        'HTI' => {
            'query' => 'QSTN'
        },
        'HTS' => {
            'mmnnoo' => 'mmnnoo',
            'query'  => 'QSTN'
        },
        'IAL' => {
            'query' => 'QSTN'
        },
        'IAT' => {
            'query' => 'QSTN'
        },
        'IFA' => {
            'query' => 'QSTN'
        },
        'IFV' => {
            'query' => 'QSTN'
        },
        'ILS' => {
            'tlpnnnnnnnnnn' => 'tlpnnnnnnnnnn'
        },
        'IMD' => {
            'ext'   => 'EXT',
            'query' => 'QSTN',
            'std'   => 'STD',
            'vdc'   => 'VDC'
        },
        'ISF' => {
            'custom' => '00',
            'day'    => '01',
            'night'  => '02',
            'query'  => 'QSTN',
            'up'     => 'UP'
        },
        'IST' => {
            'prs'   => 'prs',
            'query' => 'QSTN'
        },
        'ITI' => {
            'query' => 'QSTN'
        },
        'ITM' => {
            'mm-ss-mm-ss' => 'mm:ss/mm:ss',
            'query'       => 'QSTN'
        },
        'ITR' => {
            'cccc-tttt' => 'cccc/tttt',
            'query'     => 'QSTN'
        },
        'LMD' => {
            'stereo'                              => '00',
            'direct'                              => '01',
            'surround'                            => '02',
            'game-rpg'                            => '03',
            'thx'                                 => '04',
            'game-action'                         => '05',
            'game-rock'                           => '06',
            'mono-movie'                          => '07',
            'orchestra'                           => '08',
            'unplugged'                           => '09',
            'studio-mix'                          => '0A',
            'tv-logic'                            => '0B',
            'all-ch-stereo'                       => '0C',
            'theater-dimensional'                 => '0D',
            'game-sports'                         => '0E',
            'mono'                                => '0F',
            'pure-audio'                          => '11',
            'multiplex'                           => '12',
            'full-mono'                           => '13',
            'dolby-virtual'                       => '14',
            'dts-surround-sensation'              => '15',
            'audyssey-dsx'                        => '16',
            'whole-house'                         => '1F',
            'straight-decode'                     => '40',
            'dolby-ex'                            => '41',
            'thx-cinema'                          => '42',
            'thx-surround-ex'                     => '43',
            'thx-music'                           => '44',
            'thx-games'                           => '45',
            'thx-cinema'                          => '50',
            'thx-musicmode'                       => '51',
            'thx-games'                           => '52',
            'pliix-movie'                         => '80',
            'pliix-music'                         => '81',
            'neo-x-cinema'                        => '82',
            'neo-x-music'                         => '83',
            'pliix-thx-cinema'                    => '84',
            'neo-x-thx-cinema'                    => '85',
            'pliix-game'                          => '86',
            'neural-surr'                         => '87',
            'neural-thx'                          => '88',
            'pliix-thx-games'                     => '89',
            'neo-x-thx-games'                     => '8A',
            'pliix-thx-music'                     => '8B',
            'neo-x-thx-music'                     => '8C',
            'neural-thx-cinema'                   => '8D',
            'neural-thx-music'                    => '8E',
            'neural-thx-games'                    => '8F',
            'pliiz-height'                        => '90',
            'neo-x-cinema-dts-surround-sensation' => '91',
            'neo-x-music-dts-surround-sensation'  => '92',
            'neural-digital-music'                => '93',
            'pliiz-height-thx-cinema'             => '94',
            'pliiz-height-thx-music'              => '95',
            'pliiz-height-thx-games'              => '96',
            'pliiz-height-thx-u2-cinema'          => '97',
            'pliiz-height-thx-u2-music'           => '98',
            'pliiz-height-thx-u2-games'           => '99',
            'neo-x-game'                          => '9A',
            'plii-movie-audyssey-dsx'             => 'A0',
            'plii-music-audyssey-dsx'             => 'A1',
            'plii-game-audyssey-dsx'              => 'A2',
            'neo-x-cinema-audyssey-dsx'           => 'A3',
            'neo-x-music-audyssey-dsx'            => 'A4',
            'neural-surround-audyssey-dsx'        => 'A5',
            'neural-digital-music-audyssey-dsx'   => 'A6',
            'dolby-ex-audyssey-dsx'               => 'A7',
            'down'                                => 'DOWN',
            'game'                                => 'GAME',
            'movie'                               => 'MOVIE',
            'music'                               => 'MUSIC',
            'query'                               => 'QSTN',
            'up'                                  => 'UP',
        },
        'LTN' => {
            'auto-dolby-truehd' => '03',
            'high-dolbydigital' => '02',
            'low-dolbydigital'  => '01',
            'off'               => '00',
            'on-dolby-truehd'   => '01',
            'query'             => 'QSTN',
            'up'                => 'UP'
        },
        'MEM' => {
            'lock' => 'LOCK',
            'rcl'  => 'RCL',
            'str'  => 'STR',
            'unlk' => 'UNLK'
        },
        'MOT' => {
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'MVL' => {
            'level-down'          => 'DOWN',
            'level-down-1db-step' => 'DOWN1',
            'level-up'            => 'UP',
            'level-up-1db-step'   => 'UP1',
            'query'               => 'QSTN',
            'xrange(100)'         => '(0, 100)',
            'xrange(80)'          => '(0, 80)'
        },
        'NAL' => {
            'query' => 'QSTN'
        },
        'NAT' => {
            'query' => 'QSTN'
        },
        'NDS' => {
            'nfr'   => 'nfr',
            'query' => 'QSTN'
        },
        'NJA' => {
            'tp-xx-xx-xx-xx-xx-xx' => 'tp{xx}{xx}{xx}{xx}{xx}{xx}',
            'off'                  => 'DIS',
            'on'                   => 'ENA',
            'bmp'                  => 'BMP',
            'link'                 => 'LINK',
            'up'                   => 'UP',
            'query'                => 'QSTN',
        },
        'NKY' => {
            'll' => 'll'
        },
        'NLS' => {
            'ti' => 'ti'
        },
        'NLA' => {
            'Lzzzzllxxxxyyyy' => 'Lzzzzllxxxxyyyy',
            'Izzzzllxxxx----' => 'Izzzzllxxxx----'
        },
        'NMD' => {
            'ext'   => 'EXT',
            'query' => 'QSTN',
            'std'   => 'STD',
            'vdc'   => 'VDC'
        },
        'NPR' => {
            'set'           => 'SET',
            'xrange(1, 40)' => '(1, 40)'
        },

        #        'NPU' => {
        #            '' => ''
        #        },
        'NSB' => {
            'off'   => 'OFF',
            'on'    => 'ON',
            'query' => 'QSTN'
        },
        'NST' => {
            'prs'   => 'prs',
            'query' => 'QSTN'
        },
        'NSV' => {
            'DLNA'                    => '00',
            'My_Favorites'            => '01',
            'vTuner'                  => '02',
            'SiriusXM_Internet_Radio' => '03',
            'Pandora_Internet_Radio'  => '04',
            'Rhapsody'                => '05',
            'Last.fm_Internet_Radio'  => '06',
            'Napster'                 => '07',
            'Slacker_Personal_Radio'  => '08',
            'Mediafly'                => '09',
            'Spotify'                 => '0A',
            'AUPEO!_PERSONAL_RADIO'   => '0B',
            'radiko.jp'               => '0C',
            'e-onkyo_music'           => '0D',
            'TuneIn'                  => '0E',
            'MP3tunes'                => '0F',
            'simfy'                   => '10',
            'Home_Media'              => '11',
        },
        'NRI' => {
            'query' => 'QSTN'
        },
        'NTC' => {
            '0'        => '0',
            '1'        => '1',
            '2'        => '2',
            '3'        => '3',
            '4'        => '4',
            '5'        => '5',
            '6'        => '6',
            '7'        => '7',
            '8'        => '8',
            '9'        => '9',
            'album'    => 'ALBUM',
            'artist'   => 'ARTIST',
            'caps'     => 'CAPS',
            'chdn'     => 'CHDN',
            'chup'     => 'CHUP',
            'delete'   => 'DELETE',
            'display'  => 'DISPLAY',
            'down'     => 'DOWN',
            'ff'       => 'FF',
            'genre'    => 'GENRE',
            'language' => 'LANGUAGE',
            'left'     => 'LEFT',
            'list'     => 'LIST',
            'location' => 'LOCATION',
            'men'      => 'MENU',
            'mode'     => 'MODE',
            'pause'    => 'PAUSE',
            'play'     => 'PLAY',
            'playlist' => 'PLAYLIST',
            'random'   => 'RANDOM',
            'repeat'   => 'REPEAT',
            'return'   => 'RETURN',
            'rew'      => 'REW',
            'right'    => 'RIGHT',
            'select'   => 'SELECT',
            'setup'    => 'SETUP',
            'stop'     => 'STOP',
            'top'      => 'TOP',
            'trdn'     => 'TRDN',
            'trup'     => 'TRUP',
            'up'       => 'UP'
        },
        'NTI' => {
            'query' => 'QSTN'
        },
        'NTM' => {
            'mm-ss-mm-ss' => 'mm:ss/mm:ss',
            'query'       => 'QSTN'
        },
        'NTS' => {
            'mm-ss' => 'mm:ss',
        },
        'NTR' => {
            'cccc-tttt' => 'cccc/tttt',
            'query'     => 'QSTN'
        },
        'OSD' => {
            'audio' => 'AUDIO',
            'down'  => 'DOWN',
            'enter' => 'ENTER',
            'exit'  => 'EXIT',
            'home'  => 'HOME',
            'left'  => 'LEFT',
            'men'   => 'MENU',
            'right' => 'RIGHT',
            'up'    => 'UP',
            'video' => 'VIDEO'
        },
        'PRS' => {
            'xrange(1, 40)' => '(1, 40)',
            'xrange(1, 30)' => '(1, 30)',
            'up'            => 'UP',
            'down'          => 'DOWN',
            'query'         => 'QSTN',
        },
        'PRM' => {
            'xrange(1, 40)' => '(1, 40)',
            'xrange(1, 30)' => '(1, 30)'
        },
        'PTS' => {
            'enter'      => 'ENTER',
            'xrange(30)' => '(0, 30)'
        },
        'PMB' => {
            'off'    => '00',
            'on'     => '01',
            'toggle' => 'TG',
            'query'  => 'QSTN'
        },
        'PWR' => {
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN'
        },
        'RAS' => {
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'RDS' => {
            '00' => '00',
            '01' => '01',
            '02' => '02',
            'up' => 'UP'
        },
        'RES' => {
            '1080i'       => '04',
            '1080p'       => '07',
            '24fs'        => '07',
            '480p'        => '02',
            '4k-upcaling' => '08',
            '720p'        => '03',
            'auto'        => '01',
            'query'       => 'QSTN',
            'source'      => '06',
            'through'     => '00',
            'up'          => 'UP'
        },
        'SAT' => {
            'query' => 'QSTN'
        },
        'SCH' => {
            'down'        => 'DOWN',
            'query'       => 'QSTN',
            'up'          => 'UP',
            'xrange(597)' => '(0, 597)'
        },
        'SCN' => {
            'query' => 'QSTN'
        },
        'SCT' => {
            'down'  => 'DOWN',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'SLA' => {
            'analog'        => '02',
            'arc'           => '07',
            'auto'          => '00',
            'balance'       => '06',
            'coax'          => '05',
            'hdmi'          => '04',
            'ilink'         => '03',
            'multi-channel' => '01',
            'opt'           => '05',
            'query'         => 'QSTN',
            'up'            => 'UP'
        },
        'SLC' => {
            'chsel' => 'CHSEL',
            'down'  => 'DOWN',
            'test'  => 'TEST',
            'up'    => 'UP'
        },
        'SLI' => {
            '07'              => '07',
            '08'              => '08',
            '09'              => '09',
            'am'              => '25',
            'aux1'            => '03',
            'aux2'            => '04',
            'bd'              => '10',
            'cbl'             => '01',
            'cd'              => '23',
            'dlna'            => '27',
            'down'            => 'DOWN',
            'dvd'             => '10',
            'dvr'             => '00',
            'fm'              => '24',
            'game'            => '02',
            'internet-radio'  => '28',
            'iradio-favorite' => '28',
            'multi-ch'        => '30',
            'music-server'    => '27',
            'net'             => '2B',
            'network'         => '2B',
            'p4s'             => '27',
            'pc'              => '05',
            'phono'           => '22',
            'query'           => 'QSTN',
            'sat'             => '01',
            'sirius'          => '32',
            'tape'            => '20',
            'tape-1'          => '20',
            'tape2'           => '21',
            'tuner'           => '26',
            'tv'              => '23',
            'tv-cd'           => '23',
            'universal-port'  => '40',
            'up'              => 'UP',
            'usb'             => '29',
            'usb-rear'        => '2A',
            'usb-toggle'      => '2C',
            'vcr'             => '00',
            'video1'          => '00',
            'video2'          => '01',
            'video3'          => '02',
            'video4'          => '03',
            'video5'          => '04',
            'video6'          => '05',
            'video7'          => '06',
            'xm'              => '31'
        },
        'SLK' => {
            'input' => 'INPUT',
            'wrong' => 'WRONG'
        },
        'SLP' => {
            'query'         => 'QSTN',
            'off'           => 'OFF',
            'up'            => 'UP',
            'xrange(1, 90)' => '(1, 90)'
        },
        'SLR' => {
            'am'             => '25',
            'cd'             => '23',
            'dvd'            => '10',
            'fm'             => '24',
            'internet-radio' => '28',
            'multi-ch'       => '30',
            'music-server'   => '27',
            'off'            => '7F',
            'phono'          => '22',
            'query'          => 'QSTN',
            'source'         => '80',
            'tape'           => '20',
            'tape2'          => '21',
            'tuner'          => '26',
            'video1'         => '00',
            'video2'         => '01',
            'video3'         => '02',
            'video4'         => '03',
            'video5'         => '04',
            'video6'         => '05',
            'video7'         => '06',
            'xm'             => '31'
        },
        'SPA' => {
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'SPB' => {
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'SPL' => {
            'front-high'                     => 'FH',
            'front-high-front-wide-speakers' => 'HW',
            'front-wide'                     => 'FW',
            'query'                          => 'QSTN',
            'surrback'                       => 'SB',
            'surrback-front-high-speakers'   => 'FH',
            'surrback-front-wide-speakers'   => 'FW',
            'up'                             => 'UP'
        },
        'STI' => {
            'query' => 'QSTN'
        },
        'SWL' => {
            'down'               => 'DOWN',
            'query'              => 'QSTN',
            'up'                 => 'UP',
            'xrange(-15, 9, 12)' => '(-15, 0, 12)'
        },
        'SW2' => {
            'down'               => 'DOWN',
            'query'              => 'QSTN',
            'up'                 => 'UP',
            'xrange(-15, 9, 12)' => '(-15, 0, 12)'
        },
        'TCT' => {
            'b-xx'        => 'B{xx}',
            'bass-down'   => 'BDOWN',
            'bass-up'     => 'BUP',
            'query'       => 'QSTN',
            't-xx'        => 'T{xx}',
            'treble-down' => 'TDOWN',
            'treble-up'   => 'TUP'
        },
        'TFH' => {
            'b-xx'        => 'B{xx}',
            'bass-down'   => 'BDOWN',
            'bass-up'     => 'BUP',
            'query'       => 'QSTN',
            't-xx'        => 'T{xx}',
            'treble-down' => 'TDOWN',
            'treble-up'   => 'TUP'
        },
        'TFR' => {
            'b-xx'        => 'B{xx}',
            'bass-down'   => 'BDOWN',
            'bass-up'     => 'BUP',
            'query'       => 'QSTN',
            't-xx'        => 'T{xx}',
            'treble-down' => 'TDOWN',
            'treble-up'   => 'TUP'
        },
        'TFW' => {
            'b-xx'        => 'B{xx}',
            'bass-down'   => 'BDOWN',
            'bass-up'     => 'BUP',
            'query'       => 'QSTN',
            't-xx'        => 'T{xx}',
            'treble-down' => 'TDOWN',
            'treble-up'   => 'TUP'
        },
        'TGA' => {
            'off' => '00',
            'on'  => '01'
        },
        'TGB' => {
            'off' => '00',
            'on'  => '01'
        },
        'TGC' => {
            'off' => '00',
            'on'  => '01'
        },
        'TPS' => {
            'enter' => 'ENTER'
        },
        'TSB' => {
            'b-xx'        => 'B{xx}',
            'bass-down'   => 'BDOWN',
            'bass-up'     => 'BUP',
            'query'       => 'QSTN',
            't-xx'        => 'T{xx}',
            'treble-down' => 'TDOWN',
            'treble-up'   => 'TUP'
        },
        'TSR' => {
            'b-xx'        => 'B{xx}',
            'bass-down'   => 'BDOWN',
            'bass-up'     => 'BUP',
            'query'       => 'QSTN',
            't-xx'        => 'T{xx}',
            'treble-down' => 'TDOWN',
            'treble-up'   => 'TUP'
        },
        'TSW' => {
            'b-xx'      => 'B{xx}',
            'bass-down' => 'BDOWN',
            'bass-up'   => 'BUP',
            'query'     => 'QSTN'
        },
        'TUN' => {
            '0-in-direct-mode' => '0',
            '1-in-direct-mode' => '1',
            '2-in-direct-mode' => '2',
            '3-in-direct-mode' => '3',
            '4-in-direct-mode' => '4',
            '5-in-direct-mode' => '5',
            '6-in-direct-mode' => '6',
            '7-in-direct-mode' => '7',
            '8-in-direct-mode' => '8',
            '9-in-direct-mode' => '9',
            'direct'           => 'DIRECT',
            'down'             => 'DOWN',
            'query'            => 'QSTN',
            'up'               => 'UP'
        },
        'UDD' => {
            'at' => 'AT',
            'mf' => 'MF',
            'mn' => 'MN',
            'pt' => 'PT',
            'up' => 'UP'
        },
        'UDS' => {
            'query' => 'QSTN'
        },
        'UHA' => {
            'query' => 'QSTN'
        },
        'UHB' => {
            'analog' => '01',
            'auto'   => '00',
            'query'  => 'QSTN'
        },
        'UHC' => {
            'query' => 'QSTN'
        },
        'UHD' => {
            'query' => 'QSTN'
        },
        'UHP' => {
            'query'        => 'QSTN',
            'xrange(1, 8)' => '(1, 8)'
        },
        'UHS' => {
            'mmnnoo' => 'mmnnoo',
            'query'  => 'QSTN'
        },
        'UHT' => {
            'query' => 'QSTN'
        },
        'UPM' => {
            'xrange(1, 40)' => '(1, 40)'
        },
        'UPR' => {
            'down'          => 'DOWN',
            'query'         => 'QSTN',
            'up'            => 'UP',
            'xrange(1, 40)' => '(1, 40)'
        },
        'UTN' => {
            'down'  => 'DOWN',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'VOS' => {
            'component' => '01',
            'd4'        => '00',
            'query'     => 'QSTN'
        },
        'VPM' => {
            'cinema'    => '02',
            'custom'    => '01',
            'direct'    => '08',
            'game'      => '03',
            'isf-day'   => '05',
            'isf-night' => '06',
            'query'     => 'QSTN',
            'streaming' => '07',
            'through'   => '00',
            'up'        => 'UP'
        },
        'VWM' => {
            '4-3'        => '01',
            'auto'       => '00',
            'full'       => '02',
            'query'      => 'QSTN',
            'smart-zoom' => '05',
            'up'         => 'UP',
            'zoom'       => '04'
        },
        'XAT' => {
            'query' => 'QSTN'
        },
        'XCH' => {
            'down'        => 'DOWN',
            'query'       => 'QSTN',
            'up'          => 'UP',
            'xrange(597)' => '(0, 597)'
        },
        'XCN' => {
            'query' => 'QSTN'
        },
        'XCT' => {
            'down'  => 'DOWN',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'XTI' => {
            'query' => 'QSTN'
        }
    },
    '2' => {
        'LMZ' => {
            'direct'    => '01',
            'dvs'       => '88',
            'mono'      => '0F',
            'multiplex' => '12',
            'stereo'    => '00'
        },
        'LTZ' => {
            'high'  => '02',
            'low'   => '01',
            'off'   => '00',
            'query' => 'QSTN',
            'up'    => 'UP'
        },
        'NPZ' => {
            'xrange(1, 40)' => '(1, 40)'
        },
        'NTC' => {
            'pausez' => 'PAUSEz',
            'playz'  => 'PLAYz',
            'stopz'  => 'STOPz',
            'trdnz'  => 'TRDNz',
            'trupz'  => 'TRUPz'
        },
        'NTZ' => {
            'chdn'    => 'CHDN',
            'chup'    => 'CHUP',
            'display' => 'DISPLAY',
            'down'    => 'DOWN',
            'ff'      => 'FF',
            'left'    => 'LEFT',
            'pause'   => 'PAUSE',
            'play'    => 'PLAY',
            'random'  => 'RANDOM',
            'repeat'  => 'REPEAT',
            'return'  => 'RETURN',
            'rew'     => 'REW',
            'right'   => 'RIGHT',
            'select'  => 'SELECT',
            'stop'    => 'STOP',
            'trdn'    => 'TRDN',
            'trup'    => 'TRUP',
            'up'      => 'UP'
        },
        'PRZ' => {
            'down'          => 'DOWN',
            'query'         => 'QSTN',
            'up'            => 'UP',
            'xrange(1, 40)' => '(1, 40)',
            'xrange(1, 30)' => '(1, 30)'
        },
        'RAZ' => {
            'both-off' => '00',
            'on'       => '02',
            'query'    => 'QSTN',
            'up'       => 'UP'
        },
        'SLZ' => {
            'am'              => '25',
            'aux1'            => '03',
            'aux2'            => '04',
            'bd'              => '10',
            'cbl'             => '01',
            'cd'              => '23',
            'dlna'            => '27',
            'down'            => 'DOWN',
            'dvd'             => '10',
            'dvr'             => '00',
            'fm'              => '24',
            'game'            => '02',
            'hidden1'         => '07',
            'hidden2'         => '08',
            'hidden3'         => '09',
            'internet-radio'  => '28',
            'iradio-favorite' => '28',
            'multi-ch'        => '30',
            'music-server'    => '27',
            'net'             => '2B',
            'network'         => '2B',
            'off'             => '7F',
            'p4s'             => '27',
            'pc'              => '05',
            'phono'           => '22',
            'query'           => 'QSTN',
            'sat'             => '01',
            'sirius'          => '32',
            'source'          => '80',
            'tape'            => '20',
            'tape2'           => '21',
            'tuner'           => '26',
            'tv'              => '23',
            'tv-cd'           => '23',
            'universal-port'  => '40',
            'up'              => 'UP',
            'usb'             => '29',
            'usb-rear'        => '2A',
            'usb-toggle'      => '2C',
            'vcr'             => '00',
            'video1'          => '00',
            'video2'          => '01',
            'video3'          => '02',
            'video4'          => '03',
            'video5'          => '04',
            'video6'          => '05',
            'video7'          => '06',
            'xm'              => '31'
        },
        'TUZ' => {
            '0-in-direct-mode' => '0',
            '1-in-direct-mode' => '1',
            '2-in-direct-mode' => '2',
            '3-in-direct-mode' => '3',
            '4-in-direct-mode' => '4',
            '5-in-direct-mode' => '5',
            '6-in-direct-mode' => '6',
            '7-in-direct-mode' => '7',
            '8-in-direct-mode' => '8',
            '9-in-direct-mode' => '9',
            'direct'           => 'DIRECT',
            'down'             => 'DOWN',
            'query'            => 'QSTN',
            'up'               => 'UP'
        },
        'ZBL' => {
            'down'                            => 'DOWN',
            'query'                           => 'QSTN',
            'up'                              => 'UP',
            'xx-is-a-00-a-l-10-0-r-10-2-step' => '{xx}'
        },
        'ZMT' => {
            'off'    => '00',
            'on'     => '01',
            'query'  => 'QSTN',
            'toggle' => 'TG'
        },
        'ZPW' => {
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
        },
        'ZTN' => {
            'bass-down'                          => 'BDOWN',
            'bass-up'                            => 'BUP',
            'bass-xx-is-a-00-a-10-0-10-2-step'   => 'B{xx}',
            'query'                              => 'QSTN',
            'treble-down'                        => 'TDOWN',
            'treble-up'                          => 'TUP',
            'treble-xx-is-a-00-a-10-0-10-2-step' => 'T{xx}'
        },
        'ZVL' => {
            'level-down'  => 'DOWN',
            'level-up'    => 'UP',
            'query'       => 'QSTN',
            'xrange(100)' => '(0, 100)',
            'xrange(80)'  => '(0, 80)'
        }
    },
    '3' => {
        'BL3' => {
            'down'  => 'DOWN',
            'query' => 'QSTN',
            'up'    => 'UP',
            'xx'    => '{xx}'
        },
        'MT3' => {
            'off'    => '00',
            'on'     => '01',
            'query'  => 'QSTN',
            'toggle' => 'TG'
        },
        'NP3' => {
            'xrange(1, 40)' => '(1, 40)'
        },
        'NT3' => {
            'chdn'    => 'CHDN',
            'chup'    => 'CHUP',
            'display' => 'DISPLAY',
            'down'    => 'DOWN',
            'ff'      => 'FF',
            'left'    => 'LEFT',
            'pause'   => 'PAUSE',
            'play'    => 'PLAY',
            'random'  => 'RANDOM',
            'repeat'  => 'REPEAT',
            'return'  => 'RETURN',
            'rew'     => 'REW',
            'right'   => 'RIGHT',
            'select'  => 'SELECT',
            'stop'    => 'STOP',
            'trdn'    => 'TRDN',
            'trup'    => 'TRUP',
            'up'      => 'UP'
        },
        'NTC' => {
            'pausez' => 'PAUSEz',
            'playz'  => 'PLAYz',
            'stopz'  => 'STOPz',
            'trdnz'  => 'TRDNz',
            'trupz'  => 'TRUPz'
        },
        'PR3' => {
            'down'          => 'DOWN',
            'query'         => 'QSTN',
            'up'            => 'UP',
            'xrange(1, 40)' => '(1, 40)',
            'xrange(1, 30)' => '(1, 30)'
        },
        'PW3' => {
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
        },
        'SL3' => {
            'am'              => '25',
            'aux1'            => '03',
            'aux2'            => '04',
            'cbl'             => '01',
            'cd'              => '23',
            'dlna'            => '27',
            'down'            => 'DOWN',
            'dvd'             => '10',
            'dvr'             => '00',
            'fm'              => '24',
            'game'            => '02',
            'hidden1'         => '07',
            'hidden2'         => '08',
            'hidden3'         => '09',
            'internet-radio'  => '28',
            'iradio-favorite' => '28',
            'multi-ch'        => '30',
            'music-server'    => '27',
            'net'             => '2B',
            'network'         => '2B',
            'p4s'             => '27',
            'pc'              => '05',
            'phono'           => '22',
            'query'           => 'QSTN',
            'sat'             => '01',
            'sirius'          => '32',
            'source'          => '80',
            'tape'            => '20',
            'tape2'           => '21',
            'tuner'           => '26',
            'tv'              => '23',
            'tv-cd'           => '23',
            'universal-port'  => '40',
            'up'              => 'UP',
            'usb'             => '29',
            'usb-rear'        => '2A',
            'usb-toggle'      => '2C',
            'vcr'             => '00',
            'video1'          => '00',
            'video2'          => '01',
            'video3'          => '02',
            'video4'          => '03',
            'video5'          => '04',
            'video6'          => '05',
            'video7'          => '06',
            'xm'              => '31'
        },
        'TN3' => {
            'b-xx'        => 'B{xx}',
            'bass-down'   => 'BDOWN',
            'bass-up'     => 'BUP',
            'query'       => 'QSTN',
            't-xx'        => 'T{xx}',
            'treble-down' => 'TDOWN',
            'treble-up'   => 'TUP'
        },
        'TU3' => {
            '0-in-direct-mode' => '0',
            '1-in-direct-mode' => '1',
            '2-in-direct-mode' => '2',
            '3-in-direct-mode' => '3',
            '4-in-direct-mode' => '4',
            '5-in-direct-mode' => '5',
            '6-in-direct-mode' => '6',
            '7-in-direct-mode' => '7',
            '8-in-direct-mode' => '8',
            '9-in-direct-mode' => '9',
            'direct'           => 'DIRECT',
            'down'             => 'DOWN',
            'query'            => 'QSTN',
            'up'               => 'UP'
        },
        'VL3' => {
            'level-down'  => 'DOWN',
            'level-up'    => 'UP',
            'query'       => 'QSTN',
            'xrange(100)' => '(0, 100)',
            'xrange(80)'  => '(0, 80)'
        }
    },
    '4' => {
        'MT4' => {
            'off'    => '00',
            'on'     => '01',
            'query'  => 'QSTN',
            'toggle' => 'TG'
        },
        'NP4' => {
            'xrange(1, 40)' => '(1, 40)'
        },
        'NT4' => {
            'display' => 'DISPLAY',
            'down'    => 'DOWN',
            'ff'      => 'FF',
            'left'    => 'LEFT',
            'pause'   => 'PAUSE',
            'play'    => 'PLAY',
            'random'  => 'RANDOM',
            'repeat'  => 'REPEAT',
            'return'  => 'RETURN',
            'rew'     => 'REW',
            'right'   => 'RIGHT',
            'select'  => 'SELECT',
            'stop'    => 'STOP',
            'trdn'    => 'TRDN',
            'trup'    => 'TRUP',
            'up'      => 'UP'
        },
        'NTC' => {
            'pausez' => 'PAUSEz',
            'playz'  => 'PLAYz',
            'stopz'  => 'STOPz',
            'trdnz'  => 'TRDNz',
            'trupz'  => 'TRUPz'
        },
        'PR4' => {
            'down'          => 'DOWN',
            'query'         => 'QSTN',
            'up'            => 'UP',
            'xrange(1, 40)' => '(1, 40)',
            'xrange(1, 30)' => '(1, 30)'
        },
        'PW4' => {
            'off'   => '00',
            'on'    => '01',
            'query' => 'QSTN',
        },
        'SL4' => {
            'am'              => '25',
            'aux1'            => '03',
            'aux2'            => '04',
            'cbl'             => '01',
            'cd'              => '23',
            'dlna'            => '27',
            'down'            => 'DOWN',
            'dvd'             => '10',
            'dvr'             => '00',
            'fm'              => '24',
            'game'            => '02',
            'hidden1'         => '07',
            'hidden2'         => '08',
            'hidden3'         => '09',
            'internet-radio'  => '28',
            'iradio-favorite' => '28',
            'multi-ch'        => '30',
            'music-server'    => '27',
            'net'             => '2B',
            'network'         => '2B',
            'p4s'             => '27',
            'phono'           => '22',
            'query'           => 'QSTN',
            'sat'             => '01',
            'sirius'          => '32',
            'source'          => '80',
            'tape'            => '20',
            'tape-1'          => '20',
            'tape2'           => '21',
            'tuner'           => '26',
            'tv'              => '23',
            'tv-cd'           => '23',
            'universal-port'  => '40',
            'up'              => 'UP',
            'usb'             => '29',
            'usb-rear'        => '2A',
            'usb-toggle'      => '2C',
            'vcr'             => '00',
            'video1'          => '00',
            'video2'          => '01',
            'video3'          => '02',
            'video4'          => '03',
            'video5'          => '04',
            'video6'          => '05',
            'video7'          => '06',
            'xm'              => '31'
        },
        'TU4' => {
            '0-in-direct-mode' => '0',
            '1-in-direct-mode' => '1',
            '2-in-direct-mode' => '2',
            '3-in-direct-mode' => '3',
            '4-in-direct-mode' => '4',
            '5-in-direct-mode' => '5',
            '6-in-direct-mode' => '6',
            '7-in-direct-mode' => '7',
            '8-in-direct-mode' => '8',
            '9-in-direct-mode' => '9',
            'direct'           => 'DIRECT',
            'down'             => 'DOWN',
            'query'            => 'QSTN',
            'up'               => 'UP'
        },
        'VL4' => {
            'level-down'  => 'DOWN',
            'level-up'    => 'UP',
            'query'       => 'QSTN',
            'xrange(100)' => '(0, 100)',
            'xrange(80)'  => '(0, 80)'
        }
    }
};

# ----------------Complete command reference database-----------------------
my $ONKYO_cmddb = {
    '1' => {
        'PMB',
        {
            'description' => 'Phase Matching Bass Command',
            'name'        => 'phase-matching-bass',
            'values'      => {
                '00',
                {
                    'description' => 'sets Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets On',
                    'name'        => 'on'
                },
                'TG',
                {
                    'description' => 'sets Phase Matching Bass Wrap-Around Up',
                    'name'        => 'toggle'
                },
                'QSTN',
                {
                    'description' => 'gets Phase Matching Bass',
                    'name'        => 'query'
                }
            }
        },
        'PWR',
        {
            'description' => 'System Power Command',
            'name'        => 'power',
            'values'      => {
                '00',
                {
                    'description' => 'sets System Standby',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets System On',
                    'name'        => 'on'
                },
                'QSTN',
                {
                    'description' => 'gets the System Power Status',
                    'name'        => 'query'
                }
            }
        },
        'AMT',
        {
            'description' => 'Audio Muting Command',
            'name'        => 'mute',
            'values'      => {
                '00',
                {
                    'description' => 'sets Audio Muting Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Audio Muting On',
                    'name'        => 'on'
                },
                'TG',
                {
                    'description' => 'sets Audio Muting Wrap-Around',
                    'name'        => 'toggle'
                },
                'QSTN',
                {
                    'description' => 'gets the Audio Muting State',
                    'name'        => 'query'
                }
            }
        },
        'SPA',
        {
            'description' => 'Speaker A Command',
            'name'        => 'speaker-a',
            'values'      => {
                '00',
                {
                    'description' => 'sets Speaker Off',
                    'name'        => 'off'
                },
                '01',
                { 'description' => 'sets Speaker On', 'name' => 'on' },
                'UP',
                {
                    'description' => 'sets Speaker Switch Wrap-Around',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets the Speaker State',
                    'name'        => 'query'
                }
            }
        },
        'SPB',
        {
            'description' => 'Speaker B Command',
            'name'        => 'speaker-b',
            'values'      => {
                '00',
                {
                    'description' => 'sets Speaker Off',
                    'name'        => 'off'
                },
                '01',
                { 'description' => 'sets Speaker On', 'name' => 'on' },
                'UP',
                {
                    'description' => 'sets Speaker Switch Wrap-Around',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets the Speaker State',
                    'name'        => 'query'
                }
            }
        },
        'SPL',
        {
            'description' => 'Speaker Layout Command',
            'name'        => 'speaker-layout',
            'values'      => {
                'SB',
                {
                    'description' => 'sets SurrBack Speaker',
                    'name'        => 'surrback'
                },
                'FH',
                {
                    'description' =>
                      'sets Front High Speaker / SurrBack+Front High Speakers',
                    'name' => { 'front-high', 'surrback-front-high-speakers' }
                },
                'FW',
                {
                    'description' =>
                      'sets Front Wide Speaker / SurrBack+Front Wide Speakers',
                    'name' => { 'front-wide', 'surrback-front-wide-speakers' }
                },
                'HW',
                {
                    'description' => 'sets, Front High+Front Wide Speakers',
                    'name'        => ['front-high-front-wide-speakers']
                },
                'UP',
                {
                    'description' => 'sets Speaker Switch Wrap-Around',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets the Speaker State',
                    'name'        => 'query'
                }
            }
        },
        'MVL',
        {
            'description' => 'Master Volume Command',
            'name'        => 'volume',
            'values'      => {
                '{0,100}',
                {
                    'description' =>
                      'Volume Level 0 100 { In hexadecimal representation}',
                    'name' => 'None'
                },
                '{0,80}',
                {
                    'description' =>
                      'Volume Level 0 80 { In hexadecimal representation}',
                    'name' => 'None'
                },
                'UP',
                {
                    'description' => 'sets Volume Level Up',
                    'name'        => 'level-up'
                },
                'DOWN',
                {
                    'description' => 'sets Volume Level Down',
                    'name'        => 'level-down'
                },
                'UP1',
                {
                    'description' => 'sets Volume Level Up 1dB Step',
                    'name'        => 'level-up-1db-step'
                },
                'DOWN1',
                {
                    'description' => 'sets Volume Level Down 1dB Step',
                    'name'        => 'level-down-1db-step'
                },
                'QSTN',
                {
                    'description' => 'gets the Volume Level',
                    'name'        => 'query'
                }
            }
        },
        'TFR',
        {
            'description' => 'Tone{Front} Command',
            'name'        => 'tone-front',
            'values'      => {
                'B{xx}',
                {
                    'description' =>
'Front Bass {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 'b-xx'
                },
                'T{xx}',
                {
                    'description' =>
'Front Treble {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 't-xx'
                },
                'BUP',
                {
                    'description' => 'sets Front Bass up{2 step}',
                    'name'        => 'bass-up'
                },
                'BDOWN',
                {
                    'description' => 'sets Front Bass down{2 step}',
                    'name'        => 'bass-down'
                },
                'TUP',
                {
                    'description' => 'sets Front Treble up{2 step}',
                    'name'        => 'treble-up'
                },
                'TDOWN',
                {
                    'description' => 'sets Front Treble down{2 step}',
                    'name'        => 'treble-down'
                },
                'QSTN',
                {
                    'description' => 'gets Front Tone {"BxxTxx"}',
                    'name'        => 'query'
                }
            }
        },
        'TFW',
        {
            'description' => 'Tone{Front Wide} Command',
            'name'        => 'tone-front-wide',
            'values'      => {
                'B{xx}',
                {
                    'description' =>
'Front Wide Bass {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 'b-xx'
                },
                'T{xx}',
                {
                    'description' =>
'Front Wide Treble {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 't-xx'
                },
                'BUP',
                {
                    'description' => 'sets Front Wide Bass up{2 step}',
                    'name'        => 'bass-up'
                },
                'BDOWN',
                {
                    'description' => 'sets Front Wide Bass down{2 step}',
                    'name'        => 'bass-down'
                },
                'TUP',
                {
                    'description' => 'sets Front Wide Treble up{2 step}',
                    'name'        => 'treble-up'
                },
                'TDOWN',
                {
                    'description' => 'sets Front Wide Treble down{2 step}',
                    'name'        => 'treble-down'
                },
                'QSTN',
                {
                    'description' => 'gets Front Wide Tone {"BxxTxx"}',
                    'name'        => 'query'
                }
            }
        },
        'TFH',
        {
            'description' => 'Tone{Front High} Command',
            'name'        => 'tone-front-high',
            'values'      => {
                'B{xx}',
                {
                    'description' =>
'Front High Bass {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 'b-xx'
                },
                'T{xx}',
                {
                    'description' =>
'Front High Treble {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 't-xx'
                },
                'BUP',
                {
                    'description' => 'sets Front High Bass up{2 step}',
                    'name'        => 'bass-up'
                },
                'BDOWN',
                {
                    'description' => 'sets Front High Bass down{2 step}',
                    'name'        => 'bass-down'
                },
                'TUP',
                {
                    'description' => 'sets Front High Treble up{2 step}',
                    'name'        => 'treble-up'
                },
                'TDOWN',
                {
                    'description' => 'sets Front High Treble down{2 step}',
                    'name'        => 'treble-down'
                },
                'QSTN',
                {
                    'description' => 'gets Front High Tone {"BxxTxx"}',
                    'name'        => 'query'
                }
            }
        },
        'TCT',
        {
            'description' => 'Tone{Center} Command',
            'name'        => 'tone-center',
            'values'      => {
                'B{xx}',
                {
                    'description' =>
'Center Bass {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 'b-xx'
                },
                'T{xx}',
                {
                    'description' =>
'Center Treble {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 't-xx'
                },
                'BUP',
                {
                    'description' => 'sets Center Bass up{2 step}',
                    'name'        => 'bass-up'
                },
                'BDOWN',
                {
                    'description' => 'sets Center Bass down{2 step}',
                    'name'        => 'bass-down'
                },
                'TUP',
                {
                    'description' => 'sets Center Treble up{2 step}',
                    'name'        => 'treble-up'
                },
                'TDOWN',
                {
                    'description' => 'sets Center Treble down{2 step}',
                    'name'        => 'treble-down'
                },
                'QSTN',
                {
                    'description' => 'gets Cetner Tone {"BxxTxx"}',
                    'name'        => 'query'
                }
            }
        },
        'TSR',
        {
            'description' => 'Tone{Surround} Command',
            'name'        => 'tone-surround',
            'values'      => {
                'B{xx}',
                {
                    'description' =>
'Surround Bass {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 'b-xx'
                },
                'T{xx}',
                {
                    'description' =>
'Surround Treble {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 't-xx'
                },
                'BUP',
                {
                    'description' => 'sets Surround Bass up{2 step}',
                    'name'        => 'bass-up'
                },
                'BDOWN',
                {
                    'description' => 'sets Surround Bass down{2 step}',
                    'name'        => 'bass-down'
                },
                'TUP',
                {
                    'description' => 'sets Surround Treble up{2 step}',
                    'name'        => 'treble-up'
                },
                'TDOWN',
                {
                    'description' => 'sets Surround Treble down{2 step}',
                    'name'        => 'treble-down'
                },
                'QSTN',
                {
                    'description' => 'gets Surround Tone {"BxxTxx"}',
                    'name'        => 'query'
                }
            }
        },
        'TSB',
        {
            'description' => 'Tone{Surround Back} Command',
            'name'        => 'tone-surround-back',
            'values'      => {
                'B{xx}',
                {
                    'description' =>
'Surround Back Bass {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 'b-xx'
                },
                'T{xx}',
                {
                    'description' =>
'Surround Back Treble {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 't-xx'
                },
                'BUP',
                {
                    'description' => 'sets Surround Back Bass up{2 step}',
                    'name'        => 'bass-up'
                },
                'BDOWN',
                {
                    'description' => 'sets Surround Back Bass down{2 step}',
                    'name'        => 'bass-down'
                },
                'TUP',
                {
                    'description' => 'sets Surround Back Treble up{2 step}',
                    'name'        => 'treble-up'
                },
                'TDOWN',
                {
                    'description' => 'sets Surround Back Treble down{2 step}',
                    'name'        => 'treble-down'
                },
                'QSTN',
                {
                    'description' => 'gets Surround Back Tone {"BxxTxx"}',
                    'name'        => 'query'
                }
            }
        },
        'TSW',
        {
            'description' => 'Tone{Subwoofer} Command',
            'name'        => 'tone-subwoofer',
            'values'      => {
                'B{xx}',
                {
                    'description' =>
'Subwoofer Bass {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 'b-xx'
                },
                'BUP',
                {
                    'description' => 'sets Subwoofer Bass up{2 step}',
                    'name'        => 'bass-up'
                },
                'BDOWN',
                {
                    'description' => 'sets Subwoofer Bass down{2 step}',
                    'name'        => 'bass-down'
                },
                'QSTN',
                {
                    'description' => 'gets Subwoofer Tone {"BxxTxx"}',
                    'name'        => 'query'
                }
            }
        },
        'SLP',
        {
            'description' => 'Sleep Set Command',
            'name'        => 'sleep',
            'values'      => {
                "{1,90}",
                {
                    'description' =>
'sets Sleep Time 1 - 90min { In hexadecimal representation}',
                    'name' => 'time-1-90min'
                },
                'OFF',
                {
                    'description' => 'sets Sleep Time Off',
                    'name'        => 'off'
                },
                '00',
                {
                    'description' => 'return value if Sleep Time Off',
                    'name'        => 'off'
                },
                'UP',
                {
                    'description' => 'sets Sleep Time Wrap-Around UP',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Sleep Time',
                    'name'        => 'query'
                }
            }
        },
        'SLC',
        {
            'description' => 'Speaker Level Calibration Command',
            'name'        => 'speaker-level-calibration',
            'values'      => {
                'TEST',
                {
                    'description' => 'TEST Key',
                    'name'        => 'test'
                },
                'CHSEL',
                {
                    'description' => 'CH SEL Key',
                    'name'        => 'chsel'
                },
                'UP',
                { 'description' => 'LEVEL + Key', 'name' => 'up' },
                'DOWN',
                { 'description' => 'LEVEL KEY', 'name' => 'down' }
            }
        },
        'SWL',
        {
            'description' => 'Subwoofer {temporary} Level Command',
            'name'        => 'subwoofer-temporary-level',
            'values'      => {
                '{-15,0,12}',
                {
                    'description' => 'sets Subwoofer Level -15dB - 0dB - +12dB',
                    'name'        => '15db-0db-12db'
                },
                'UP',
                { 'description' => 'LEVEL + Key', 'name' => 'up' },
                'DOWN',
                { 'description' => 'LEVEL KEY', 'name' => 'down' },
                'QSTN',
                {
                    'description' => 'gets the Subwoofer Level',
                    'name'        => 'query'
                }
            }
        },
        'SW2',
        {
            'description' => 'Subwoofer2 {temporary} Level Command',
            'name'        => 'subwoofer2-temporary-level',
            'values'      => {
                '{-15,0,12}',
                {
                    'description' => 'sets Subwoofer Level -15dB - 0dB - +12dB',
                    'name'        => '15db-0db-12db'
                },
                'UP',
                { 'description' => 'LEVEL + Key', 'name' => 'up' },
                'DOWN',
                { 'description' => 'LEVEL KEY', 'name' => 'down' },
                'QSTN',
                {
                    'description' => 'gets the Subwoofer Level',
                    'name'        => 'query'
                }
            }
        },
        'CTL',
        {
            'description' => 'Center {temporary} Level Command',
            'name'        => 'center-temporary-level',
            'values'      => {
                '{-12,0,12}',
                {
                    'description' => 'sets Center Level -12dB - 0dB - +12dB',
                    'name'        => '12db-0db-12db'
                },
                'UP',
                { 'description' => 'LEVEL + Key', 'name' => 'up' },
                'DOWN',
                { 'description' => 'LEVEL KEY', 'name' => 'down' },
                'QSTN',
                {
                    'description' => 'gets the Subwoofer Level',
                    'name'        => 'query'
                }
            }
        },
        'DIF',
        {
            'description' => 'Display Mode Command',
            'name'        => 'display-mode',
            'values'      => {
                '00',
                {
                    'description' => 'sets Selector + Volume Display Mode',
                    'name'        => 'volume'
                },
                '01',
                {
                    'description' =>
                      'sets Selector + Listening Mode Display Mode',
                    'name' => 'listening'
                },
                '02',
                {
                    'description' =>
                      'Display Digital Format{temporary display}',
                    'name' => '02'
                },
                '03',
                {
                    'description' => 'Display Video Format{temporary display}',
                    'name'        => '03'
                },
                'TG',
                {
                    'description' => 'sets Display Mode Wrap-Around Up',
                    'name'        => 'toggle'
                },
                'QSTN',
                {
                    'description' => 'gets The Display Mode',
                    'name'        => 'query'
                }
            }
        },
        'DIM',
        {
            'description' => 'Dimmer Level Command',
            'name'        => 'dimmer-level',
            'values'      => {
                '00',
                {
                    'description' => 'sets Dimmer Level "Bright"',
                    'name'        => 'bright'
                },
                '01',
                {
                    'description' => 'sets Dimmer Level "Dim"',
                    'name'        => 'dim'
                },
                '02',
                {
                    'description' => 'sets Dimmer Level "Dark"',
                    'name'        => 'dark'
                },
                '03',
                {
                    'description' => 'sets Dimmer Level "Shut-Off"',
                    'name'        => 'shut-off'
                },
                '08',
                {
                    'description' => 'sets Dimmer Level "Bright & LED OFF"',
                    'name'        => 'bright-led-off'
                },
                'DIM',
                {
                    'description' => 'sets Dimmer Level Wrap-Around Up',
                    'name'        => 'dim'
                },
                'QSTN',
                {
                    'description' => 'gets The Dimmer Level',
                    'name'        => 'query'
                }
            }
        },
        'OSD',
        {
            'description' => 'Setup Operation Command',
            'name'        => 'setup',
            'values'      => {
                'MENU',
                {
                    'description' => 'Menu Key',
                    'name'        => 'menu'
                },
                'UP',
                { 'description' => 'Up Key', 'name' => 'up' },
                'DOWN',
                { 'description' => 'Down Key', 'name' => 'down' },
                'RIGHT',
                { 'description' => 'Right Key', 'name' => 'right' },
                'LEFT',
                { 'description' => 'Left Key', 'name' => 'left' },
                'ENTER',
                { 'description' => 'Enter Key', 'name' => 'enter' },
                'EXIT',
                { 'description' => 'Exit Key', 'name' => 'exit' },
                'AUDIO',
                {
                    'description' => 'Audio Adjust Key',
                    'name'        => 'audio'
                },
                'VIDEO',
                {
                    'description' => 'Video Adjust Key',
                    'name'        => 'video'
                },
                'HOME',
                { 'description' => 'Home Key', 'name' => 'home' }
            }
        },
        'MEM',
        {
            'description' => 'Memory Setup Command',
            'name'        => 'memory-setup',
            'values'      => {
                'STR',
                {
                    'description' => 'stores memory',
                    'name'        => 'str'
                },
                'RCL',
                {
                    'description' => 'recalls memory',
                    'name'        => 'rcl'
                },
                'LOCK',
                {
                    'description' => 'locks memory',
                    'name'        => 'lock'
                },
                'UNLK',
                {
                    'description' => 'unlocks memory',
                    'name'        => 'unlk'
                }
            }
        },
        'IFA',
        {
            'description' => 'Audio Information Command',
            'name'        => 'audio-information',
            'values'      => {
                'nnnnn:nnnnn',
                {
                    'description' =>
"Infomation of Audio{Same Immediate Display ',' is separator of informations}",
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets Infomation of Audio',
                    'name'        => 'query'
                }
            }
        },
        'IFV',
        {
            'description' => 'Video Information Command',
            'name'        => 'video-information',
            'values'      => {
                'nnnnn:nnnnn',
                {
                    'description' =>
"information of Video{Same Immediate Display ',' is separator of informations}",
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets Infomation of Video',
                    'name'        => 'query'
                }
            }
        },
        'SLI',
        {
            'description' => 'Input Selector Command',
            'name'        => 'input',
            'values'      => {
                '00',
                {
                    'description' => 'sets VIDEO1, VCR/DVR',
                    'name'        => [ 'video1', 'vcr', 'dvr' ]
                },
                '01',
                {
                    'description' => 'sets VIDEO2, CBL/SAT',
                    'name'        => [ 'video2', 'cbl', 'sat' ]
                },
                '02',
                {
                    'description' => 'sets VIDEO3, GAME/TV, GAME',
                    'name'        => [ 'video3', 'game' ]
                },
                '03',
                {
                    'description' => 'sets VIDEO4, AUX1{AUX}',
                    'name'        => [ 'video4', 'aux1' ]
                },
                '04',
                {
                    'description' => 'sets VIDEO5, AUX2',
                    'name'        => [ 'video5', 'aux2' ]
                },
                '05',
                {
                    'description' => 'sets VIDEO6, PC',
                    'name'        => [ 'video6', 'pc' ]
                },
                '06',
                {
                    'description' => 'sets VIDEO7',
                    'name'        => 'video7'
                },
                '07',
                { 'description' => 'Hidden1', 'name' => '07' },
                '08',
                { 'description' => 'Hidden2', 'name' => '08' },
                '09',
                { 'description' => 'Hidden3', 'name' => '09' },
                '10',
                {
                    'description' => 'sets DVD, BD/DVD',
                    'name'        => [ 'dvd', 'bd', 'dvd' ]
                },
                '20',
                {
                    'description' => 'sets TAPE{1}, TV/TAPE',
                    'name'        => [ 'tape-1', 'tape' ]
                },
                '21',
                {
                    'description' => 'sets TAPE2',
                    'name'        => 'tape2'
                },
                '22',
                {
                    'description' => 'sets PHONO',
                    'name'        => 'phono'
                },
                '23',
                {
                    'description' => 'sets CD, TV/CD',
                    'name'        => [ 'tv-cd', 'tv', 'cd' ]
                },
                '24',
                { 'description' => 'sets FM', 'name' => 'fm' },
                '25',
                { 'description' => 'sets AM', 'name' => 'am' },
                '26',
                {
                    'description' => 'sets TUNER',
                    'name'        => 'tuner'
                },
                '27',
                {
                    'description' => 'sets MUSIC SERVER, P4S, DLNA',
                    'name'        => [ 'music-server', 'p4s', 'dlna' ]
                },
                '28',
                {
                    'description' => 'sets INTERNET RADIO, iRadio Favorite',
                    'name'        => [ 'internet-radio', 'iradio-favorite' ]
                },
                '29',
                {
                    'description' => 'sets USB/USB{Front}',
                    'name'        => ['usb']
                },
                '2A',
                {
                    'description' => 'sets USB{Rear}',
                    'name'        => 'usb-rear'
                },
                '2B',
                {
                    'description' => 'sets NETWORK, NET',
                    'name'        => [ 'network', 'net' ]
                },
                '2C',
                {
                    'description' => 'sets USB{toggle}',
                    'name'        => 'usb-toggle'
                },
                '40',
                {
                    'description' => 'sets Universal PORT',
                    'name'        => 'universal-port'
                },
                '30',
                {
                    'description' => 'sets MULTI CH',
                    'name'        => 'multi-ch'
                },
                '31',
                { 'description' => 'sets XM', 'name' => 'xm' },
                '32',
                {
                    'description' => 'sets SIRIUS',
                    'name'        => 'sirius'
                },
                'UP',
                {
                    'description' => 'sets Selector Position Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Selector Position Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Selector Position',
                    'name'        => 'query'
                }
            }
        },
        'SLR',
        {
            'description' => 'RECOUT Selector Command',
            'name'        => 'record-output',
            'values'      => {
                '00',
                {
                    'description' => 'sets VIDEO1',
                    'name'        => 'video1'
                },
                '01',
                {
                    'description' => 'sets VIDEO2',
                    'name'        => 'video2'
                },
                '02',
                {
                    'description' => 'sets VIDEO3',
                    'name'        => 'video3'
                },
                '03',
                {
                    'description' => 'sets VIDEO4',
                    'name'        => 'video4'
                },
                '04',
                {
                    'description' => 'sets VIDEO5',
                    'name'        => 'video5'
                },
                '05',
                {
                    'description' => 'sets VIDEO6',
                    'name'        => 'video6'
                },
                '06',
                {
                    'description' => 'sets VIDEO7',
                    'name'        => 'video7'
                },
                '10',
                { 'description' => 'sets DVD', 'name' => 'dvd' },
                '20',
                {
                    'description' => 'sets TAPE{1}',
                    'name'        => 'tape'
                },
                '21',
                {
                    'description' => 'sets TAPE2',
                    'name'        => 'tape2'
                },
                '22',
                {
                    'description' => 'sets PHONO',
                    'name'        => 'phono'
                },
                '23',
                { 'description' => 'sets CD', 'name' => 'cd' },
                '24',
                { 'description' => 'sets FM', 'name' => 'fm' },
                '25',
                { 'description' => 'sets AM', 'name' => 'am' },
                '26',
                {
                    'description' => 'sets TUNER',
                    'name'        => 'tuner'
                },
                '27',
                {
                    'description' => 'sets MUSIC SERVER',
                    'name'        => 'music-server'
                },
                '28',
                {
                    'description' => 'sets INTERNET RADIO',
                    'name'        => 'internet-radio'
                },
                '30',
                {
                    'description' => 'sets MULTI CH',
                    'name'        => 'multi-ch'
                },
                '31',
                { 'description' => 'sets XM', 'name' => 'xm' },
                '7F',
                { 'description' => 'sets OFF', 'name' => 'off' },
                '80',
                {
                    'description' => 'sets SOURCE',
                    'name'        => 'source'
                },
                'QSTN',
                {
                    'description' => 'gets The Selector Position',
                    'name'        => 'query'
                }
            }
        },
        'SLA',
        {
            'description' => 'Audio Selector Command',
            'name'        => 'audio-input',
            'values'      => {
                '00',
                { 'description' => 'sets AUTO', 'name' => 'auto' },
                '01',
                {
                    'description' => 'sets MULTI-CHANNEL',
                    'name'        => 'multi-channel'
                },
                '02',
                {
                    'description' => 'sets ANALOG',
                    'name'        => 'analog'
                },
                '03',
                {
                    'description' => 'sets iLINK',
                    'name'        => 'ilink'
                },
                '04',
                { 'description' => 'sets HDMI', 'name' => 'hdmi' },
                '05',
                {
                    'description' => 'sets COAX/OPT',
                    'name'        => [ 'coax', 'opt' ]
                },
                '06',
                {
                    'description' => 'sets BALANCE',
                    'name'        => 'balance'
                },
                '07',
                { 'description' => 'sets ARC', 'name' => 'arc' },
                'UP',
                {
                    'description' => 'sets Audio Selector Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Audio Selector Status',
                    'name'        => 'query'
                }
            }
        },
        'TGA',
        {
            'description' => '12V Trigger A Command',
            'name'        => '12v-trigger-a',
            'values'      => {
                '00',
                {
                    'description' => 'sets 12V Trigger A Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets 12V Trigger A On',
                    'name'        => 'on'
                }
            }
        },
        'TGB',
        {
            'description' => '12V Trigger B Command',
            'name'        => '12v-trigger-b',
            'values'      => {
                '00',
                {
                    'description' => 'sets 12V Trigger B Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets 12V Trigger B On',
                    'name'        => 'on'
                }
            }
        },
        'TGC',
        {
            'description' => '12V Trigger C Command',
            'name'        => '12v-trigger-c',
            'values'      => {
                '00',
                {
                    'description' => 'sets 12V Trigger C Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets 12V Trigger C On',
                    'name'        => 'on'
                }
            }
        },
        'VOS',
        {
            'description' => 'Video Output Selector {Japanese Model Only}',
            'name'        => 'video-output',
            'values'      => {
                '00',
                { 'description' => 'sets D4', 'name' => 'd4' },
                '01',
                {
                    'description' => 'sets Component',
                    'name'        => 'component'
                },
                'QSTN',
                {
                    'description' => 'gets The Selector Position',
                    'name'        => 'query'
                }
            }
        },
        'HDO',
        {
            'description' => 'HDMI Output Selector',
            'name'        => 'hdmi-output',
            'values'      => {
                '00',
                {
                    'description' => 'sets No, Analog',
                    'name'        => [ 'no', 'analog' ]
                },
                '01',
                {
                    'description' => 'sets Yes/Out Main, HDMI Main',
                    'name'        => [ 'yes', 'out' ]
                },
                '02',
                {
                    'description' => 'sets Out Sub, HDMI Sub',
                    'name'        => [ 'out-sub', 'sub' ]
                },
                '03',
                {
                    'description' => 'sets, Both',
                    'name'        => 'both'
                },
                '04',
                {
                    'description' => 'sets, Both{Main}',
                    'name'        => 'both-main'
                },
                '05',
                {
                    'description' => 'sets, Both{Sub}',
                    'name'        => 'both-sub'
                },
                'UP',
                {
                    'description' => 'sets HDMI Out Selector Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The HDMI Out Selector',
                    'name'        => 'query'
                }
            }
        },
        'HAO',
        {
            'description' => 'HDMI Audio Out',
            'name'        => 'hdmi-audio-out',
            'values'      => {
                '00',
                { 'description' => 'sets Off', 'name' => 'off' },
                '01',
                { 'description' => 'sets On', 'name' => 'on' },
                '02',
                { 'description' => 'sets Auto', 'name' => 'auto' },
                'UP',
                {
                    'description' => 'sets HDMI Audio Out Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets HDMI Audio Out',
                    'name'        => 'query'
                }
            }
        },
        'RES',
        {
            'description' => 'Monitor Out Resolution',
            'name'        => 'monitor-out-resolution',
            'values'      => {
                '00',
                {
                    'description' => 'sets Through',
                    'name'        => 'through'
                },
                '01',
                {
                    'description' => 'sets Auto{HDMI Output Only}',
                    'name'        => 'auto'
                },
                '02',
                { 'description' => 'sets 480p', 'name' => '480p' },
                '03',
                { 'description' => 'sets 720p', 'name' => '720p' },
                '04',
                {
                    'description' => 'sets 1080i',
                    'name'        => '1080i'
                },
                '05',
                {
                    'description' => 'sets 1080p{HDMI Output Only}',
                    'name'        => '1080p'
                },
                '07',
                {
                    'description' => 'sets 1080p/24fs{HDMI Output Only}',
                    'name'        => [ '1080p', '24fs' ]
                },
                '08',
                {
                    'description' => 'sets 4K Upcaling{HDMI Output Only}',
                    'name'        => '4k-upcaling'
                },
                '06',
                {
                    'description' => 'sets Source',
                    'name'        => 'source'
                },
                'UP',
                {
                    'description' =>
                      'sets Monitor Out Resolution Wrap-Around Up',
                    'name' => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Monitor Out Resolution',
                    'name'        => 'query'
                }
            }
        },
        'ISF',
        {
            'description' => 'ISF Mode',
            'name'        => 'isf-mode',
            'values'      => {
                '00',
                {
                    'description' => 'sets ISF Mode Custom',
                    'name'        => 'custom'
                },
                '01',
                {
                    'description' => 'sets ISF Mode Day',
                    'name'        => 'day'
                },
                '02',
                {
                    'description' => 'sets ISF Mode Night',
                    'name'        => 'night'
                },
                'UP',
                {
                    'description' => 'sets ISF Mode State Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The ISF Mode State',
                    'name'        => 'query'
                }
            }
        },
        'VWM',
        {
            'description' => 'Video Wide Mode',
            'name'        => 'video-wide-mode',
            'values'      => {
                '00',
                { 'description' => 'sets Auto', 'name' => 'auto' },
                '01',
                { 'description' => 'sets 4:3', 'name' => '4-3' },
                '02',
                { 'description' => 'sets Full', 'name' => 'full' },
                '03',
                { 'description' => 'sets Zoom', 'name' => 'zoom' },
                '04',
                {
                    'description' => 'sets Wide Zoom',
                    'name'        => 'zoom'
                },
                '05',
                {
                    'description' => 'sets Smart Zoom',
                    'name'        => 'smart-zoom'
                },
                'UP',
                {
                    'description' => 'sets Video Zoom Mode Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets Video Zoom Mode',
                    'name'        => 'query'
                }
            }
        },
        'VPM',
        {
            'description' => 'Video Picture Mode',
            'name'        => 'video-picture-mode',
            'values'      => {
                '00',
                {
                    'description' => 'sets Through',
                    'name'        => 'through'
                },
                '01',
                {
                    'description' => 'sets Custom',
                    'name'        => 'custom'
                },
                '02',
                {
                    'description' => 'sets Cinema',
                    'name'        => 'cinema'
                },
                '03',
                { 'description' => 'sets Game', 'name' => 'game' },
                '05',
                {
                    'description' => 'sets ISF Day',
                    'name'        => 'isf-day'
                },
                '06',
                {
                    'description' => 'sets ISF Night',
                    'name'        => 'isf-night'
                },
                '07',
                {
                    'description' => 'sets Streaming',
                    'name'        => 'streaming'
                },
                '08',
                {
                    'description' => 'sets Direct',
                    'name'        => 'direct'
                },
                'UP',
                {
                    'description' => 'sets Video Zoom Mode Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets Video Zoom Mode',
                    'name'        => 'query'
                }
            }
        },
        'LMD',
        {
            'description' => 'Listening Mode Command',
            'name'        => 'listening-mode',
            'values'      => {
                '00',
                {
                    'description' => 'sets STEREO',
                    'name'        => 'stereo'
                },
                '01',
                {
                    'description' => 'sets DIRECT',
                    'name'        => 'direct'
                },
                '02',
                {
                    'description' => 'sets SURROUND',
                    'name'        => 'surround'
                },
                '03',
                {
                    'description' => 'sets FILM, Game-RPG',
                    'name'        => 'game-rpg'
                },
                '04',
                { 'description' => 'sets THX', 'name' => 'thx' },
                '05',
                {
                    'description' => 'sets ACTION, Game-Action',
                    'name'        => 'game-action'
                },
                '06',
                {
                    'description' => 'sets MUSICAL, Game-Rock',
                    'name'        => 'game-rock'
                },
                '07',
                {
                    'description' => 'sets MONO MOVIE',
                    'name'        => 'mono-movie'
                },
                '08',
                {
                    'description' => 'sets ORCHESTRA',
                    'name'        => 'orchestra'
                },
                '09',
                {
                    'description' => 'sets UNPLUGGED',
                    'name'        => 'unplugged'
                },
                '0A',
                {
                    'description' => 'sets STUDIO-MIX',
                    'name'        => 'studio-mix'
                },
                '0B',
                {
                    'description' => 'sets TV LOGIC',
                    'name'        => 'tv-logic'
                },
                '0C',
                {
                    'description' => 'sets ALL CH STEREO',
                    'name'        => 'all-ch-stereo'
                },
                '0D',
                {
                    'description' => 'sets THEATER-DIMENSIONAL',
                    'name'        => 'theater-dimensional'
                },
                '0E',
                {
                    'description' => 'sets ENHANCED 7/ENHANCE, Game-Sports',
                    'name'        => 'game-sports'
                },
                '0F',
                { 'description' => 'sets MONO', 'name' => 'mono' },
                '11',
                {
                    'description' => 'sets PURE AUDIO',
                    'name'        => 'pure-audio'
                },
                '12',
                {
                    'description' => 'sets MULTIPLEX',
                    'name'        => 'multiplex'
                },
                '13',
                {
                    'description' => 'sets FULL MONO',
                    'name'        => 'full-mono'
                },
                '14',
                {
                    'description' => 'sets DOLBY VIRTUAL',
                    'name'        => 'dolby-virtual'
                },
                '15',
                {
                    'description' => 'sets DTS Surround Sensation',
                    'name'        => 'dts-surround-sensation'
                },
                '16',
                {
                    'description' => 'sets Audyssey DSX',
                    'name'        => 'audyssey-dsx'
                },
                '1F',
                {
                    'description' => 'sets Whole House Mode',
                    'name'        => 'whole-house'
                },
                '40',
                {
                    'description' => 'sets Straight Decode',
                    'name'        => 'straight-decode'
                },
                '41',
                {
                    'description' => 'sets Dolby EX',
                    'name'        => 'dolby-ex'
                },
                '42',
                {
                    'description' => 'sets THX Cinema',
                    'name'        => 'thx-cinema'
                },
                '43',
                {
                    'description' => 'sets THX Surround EX',
                    'name'        => 'thx-surround-ex'
                },
                '44',
                {
                    'description' => 'sets THX Music',
                    'name'        => 'thx-music'
                },
                '45',
                {
                    'description' => 'sets THX Games',
                    'name'        => 'thx-games'
                },
                '50',
                {
                    'description' => 'sets THX U2/S2/I/S Cinema/Cinema2',
                    'name'        => 'thx-cinema'
                },
                '51',
                {
                    'description' => 'sets THX MusicMode,THX U2/S2/I/S Music',
                    'name'        => 'thx-musicmode'
                },
                '52',
                {
                    'description' => 'sets THX Games Mode,THX U2/S2/I/S Games',
                    'name'        => 'thx-games'
                },
                '80',
                {
                    'description' => 'sets PLII/PLIIx Movie',
                    'name'        => 'pliix-movie'
                },
                '81',
                {
                    'description' => 'sets PLII/PLIIx Music',
                    'name'        => 'pliix-music'
                },
                '82',
                {
                    'description' => 'sets Neo:6 Cinema/Neo:X Cinema',
                    'name'        => 'neo-x-cinema'
                },
                '83',
                {
                    'description' => 'sets Neo:6 Music/Neo:X Music',
                    'name'        => 'neo-x-music'
                },
                '84',
                {
                    'description' => 'sets PLII/PLIIx THX Cinema',
                    'name'        => 'pliix-thx-cinema'
                },
                '85',
                {
                    'description' => 'sets Neo:6/Neo:X THX Cinema',
                    'name'        => 'neo-x-thx-cinema'
                },
                '86',
                {
                    'description' => 'sets PLII/PLIIx Game',
                    'name'        => 'pliix-game'
                },
                '87',
                {
                    'description' => 'sets Neural Surr',
                    'name'        => 'neural-surr'
                },
                '88',
                {
                    'description' => 'sets Neural THX/Neural Surround',
                    'name'        => 'neural-thx'
                },
                '89',
                {
                    'description' => 'sets PLII/PLIIx THX Games',
                    'name'        => 'pliix-thx-games'
                },
                '8A',
                {
                    'description' => 'sets Neo:6/Neo:X THX Games',
                    'name'        => 'neo-x-thx-games'
                },
                '8B',
                {
                    'description' => 'sets PLII/PLIIx THX Music',
                    'name'        => 'pliix-thx-music'
                },
                '8C',
                {
                    'description' => 'sets Neo:6/Neo:X THX Music',
                    'name'        => 'neo-x-thx-music'
                },
                '8D',
                {
                    'description' => 'sets Neural THX Cinema',
                    'name'        => 'neural-thx-cinema'
                },
                '8E',
                {
                    'description' => 'sets Neural THX Music',
                    'name'        => 'neural-thx-music'
                },
                '8F',
                {
                    'description' => 'sets Neural THX Games',
                    'name'        => 'neural-thx-games'
                },
                '90',
                {
                    'description' => 'sets PLIIz Height',
                    'name'        => 'pliiz-height'
                },
                '91',
                {
                    'description' => 'sets Neo:6 Cinema DTS Surround Sensation',
                    'name'        => 'neo-x-cinema-dts-surround-sensation'
                },
                '92',
                {
                    'description' => 'sets Neo:6 Music DTS Surround Sensation',
                    'name'        => 'neo-x-music-dts-surround-sensation'
                },
                '93',
                {
                    'description' => 'sets Neural Digital Music',
                    'name'        => 'neural-digital-music'
                },
                '94',
                {
                    'description' => 'sets PLIIz Height + THX Cinema',
                    'name'        => 'pliiz-height-thx-cinema'
                },
                '95',
                {
                    'description' => 'sets PLIIz Height + THX Music',
                    'name'        => 'pliiz-height-thx-music'
                },
                '96',
                {
                    'description' => 'sets PLIIz Height + THX Games',
                    'name'        => 'pliiz-height-thx-games'
                },
                '97',
                {
                    'description' => 'sets PLIIz Height + THX U2/S2 Cinema',
                    'name'        => 'pliiz-height-thx-u2-cinema'
                },
                '98',
                {
                    'description' => 'sets PLIIz Height + THX U2/S2 Music',
                    'name'        => 'pliiz-height-thx-u2-music'
                },
                '99',
                {
                    'description' => 'sets PLIIz Height + THX U2/S2 Games',
                    'name'        => 'pliiz-height-thx-u2-games'
                },
                '9A',
                {
                    'description' => 'sets Neo:X Game',
                    'name'        => 'neo-x-game'
                },
                'A0',
                {
                    'description' => 'sets PLIIx/PLII Movie + Audyssey DSX',
                    'name'        => 'plii-movie-audyssey-dsx'
                },
                'A1',
                {
                    'description' => 'sets PLIIx/PLII Music + Audyssey DSX',
                    'name'        => 'plii-music-audyssey-dsx'
                },
                'A2',
                {
                    'description' => 'sets PLIIx/PLII Game + Audyssey DSX',
                    'name'        => 'plii-game-audyssey-dsx'
                },
                'A3',
                {
                    'description' => 'sets Neo:6 Cinema + Audyssey DSX',
                    'name'        => 'neo-x-cinema-audyssey-dsx'
                },
                'A4',
                {
                    'description' => 'sets Neo:6 Music + Audyssey DSX',
                    'name'        => 'neo-x-music-audyssey-dsx'
                },
                'A5',
                {
                    'description' => 'sets Neural Surround + Audyssey DSX',
                    'name'        => 'neural-surround-audyssey-dsx'
                },
                'A6',
                {
                    'description' => 'sets Neural Digital Music + Audyssey DSX',
                    'name'        => 'neural-digital-music-audyssey-dsx'
                },
                'A7',
                {
                    'description' => 'sets Dolby EX + Audyssey DSX',
                    'name'        => 'dolby-ex-audyssey-dsx'
                },
                'UP',
                {
                    'description' => 'sets Listening Mode Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Listening Mode Wrap-Around Down',
                    'name'        => 'down'
                },
                'MOVIE',
                {
                    'description' => 'sets Listening Mode Wrap-Around Up',
                    'name'        => 'movie'
                },
                'MUSIC',
                {
                    'description' => 'sets Listening Mode Wrap-Around Up',
                    'name'        => 'music'
                },
                'GAME',
                {
                    'description' => 'sets Listening Mode Wrap-Around Up',
                    'name'        => 'game'
                },
                'QSTN',
                {
                    'description' => 'gets The Listening Mode',
                    'name'        => 'query'
                }
            }
        },
        'LTN',
        {
            'description' => 'Late Night Command',
            'name'        => 'late-night',
            'values'      => {
                '00',
                {
                    'description' => 'sets Late Night Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' =>
                      'sets Late Night Low@DolbyDigital,On@Dolby TrueHD',
                    'name' => [ 'low-dolbydigital', 'on-dolby-truehd' ]
                },
                '02',
                {
                    'description' =>
                      'sets Late Night High@DolbyDigital,{On@Dolby TrueHD}',
                    'name' => ['high-dolbydigital']
                },
                '03',
                {
                    'description' => 'sets Late Night Auto@Dolby TrueHD',
                    'name'        => 'auto-dolby-truehd'
                },
                'UP',
                {
                    'description' => 'sets Late Night State Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Late Night Level',
                    'name'        => 'query'
                }
            }
        },
        'RAS',
        {
            'description' => 'Cinema Filter Command',
            'name'        => 'cinema-filter',
            'values'      => {
                '00',
                {
                    'description' => 'sets Cinema Filter Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Cinema Filter On',
                    'name'        => 'on'
                },
                'UP',
                {
                    'description' => 'sets Cinema Filter State Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Cinema Filter State',
                    'name'        => 'query'
                }
            }
        },
        'ADY',
        {
            'description' => 'Audyssey 2EQ/MultEQ/MultEQ XT',
            'name'        => 'audyssey-2eq-multeq-multeq-xt',
            'values'      => {
                '00',
                {
                    'description' => 'sets Audyssey 2EQ/MultEQ/MultEQ XT Off',
                    'name'        => ['off']
                },
                '01',
                {
                    'description' =>
                      'sets Audyssey 2EQ/MultEQ/MultEQ XT On/Movie',
                    'name' => [ 'on', 'movie' ]
                },
                '02',
                {
                    'description' => 'sets Audyssey 2EQ/MultEQ/MultEQ XT Music',
                    'name'        => ['music']
                },
                'UP',
                {
                    'description' =>
                      'sets Audyssey 2EQ/MultEQ/MultEQ XT State Wrap-Around Up',
                    'name' => 'up'
                },
                'QSTN',
                {
                    'description' =>
                      'gets The Audyssey 2EQ/MultEQ/MultEQ XT State',
                    'name' => 'query'
                }
            }
        },
        'ADQ',
        {
            'description' => 'Audyssey Dynamic EQ',
            'name'        => 'audyssey-dynamic-eq',
            'values'      => {
                '00',
                {
                    'description' => 'sets Audyssey Dynamic EQ Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Audyssey Dynamic EQ On',
                    'name'        => 'on'
                },
                'UP',
                {
                    'description' =>
                      'sets Audyssey Dynamic EQ State Wrap-Around Up',
                    'name' => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Audyssey Dynamic EQ State',
                    'name'        => 'query'
                }
            }
        },
        'ADV',
        {
            'description' => 'Audyssey Dynamic Volume',
            'name'        => 'audyssey-dynamic-volume',
            'values'      => {
                '00',
                {
                    'description' => 'sets Audyssey Dynamic Volume Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Audyssey Dynamic Volume Light',
                    'name'        => 'light'
                },
                '02',
                {
                    'description' => 'sets Audyssey Dynamic Volume Medium',
                    'name'        => 'medium'
                },
                '03',
                {
                    'description' => 'sets Audyssey Dynamic Volume Heavy',
                    'name'        => 'heavy'
                },
                'UP',
                {
                    'description' =>
                      'sets Audyssey Dynamic Volume State Wrap-Around Up',
                    'name' => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Audyssey Dynamic Volume State',
                    'name'        => 'query'
                }
            }
        },
        'DVL',
        {
            'description' => 'Dolby Volume',
            'name'        => 'dolby-volume',
            'values'      => {
                '00',
                {
                    'description' => 'sets Dolby Volume Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Dolby Volume Low/On',
                    'name'        => [ 'low', 'on' ]
                },
                '02',
                {
                    'description' => 'sets Dolby Volume Mid',
                    'name'        => 'mid'
                },
                '03',
                {
                    'description' => 'sets Dolby Volume High',
                    'name'        => 'high'
                },
                'UP',
                {
                    'description' => 'sets Dolby Volume State Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Dolby Volume State',
                    'name'        => 'query'
                }
            }
        },
        'MOT',
        {
            'description' => 'Music Optimizer',
            'name'        => 'music-optimizer',
            'values'      => {
                '00',
                {
                    'description' => 'sets Music Optimizer Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Music Optimizer On',
                    'name'        => 'on'
                },
                'UP',
                {
                    'description' =>
                      'sets Music Optimizer State Wrap-Around Up',
                    'name' => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Dolby Volume State',
                    'name'        => 'query'
                }
            }
        },
        'TUN',
        {
            'description' => 'Tuning Command {Include Tuner Pack Model Only}',
            'name'        => 'tunerFrequency',
            'values'      => {
                'nnnnn',
                {
                    'description' =>
'sets Directly Tuning Frequency {FM nnn.nn MHz / AM nnnnn kHz / SR nnnnn ch}\nput 0 in the first two digits of nnnnn at SR',
                    'name' => 'None'
                },
                'DIRECT',
                {
                    'description' => 'starts/restarts Direct Tuning Mode',
                    'name'        => 'direct'
                },
                '0',
                {
                    'description' => 'sets 0 in Direct Tuning Mode',
                    'name'        => '0-in-direct-mode'
                },
                '1',
                {
                    'description' => 'sets 1 in Direct Tuning Mode',
                    'name'        => '1-in-direct-mode'
                },
                '2',
                {
                    'description' => 'sets 2 in Direct Tuning Mode',
                    'name'        => '2-in-direct-mode'
                },
                '3',
                {
                    'description' => 'sets 3 in Direct Tuning Mode',
                    'name'        => '3-in-direct-mode'
                },
                '4',
                {
                    'description' => 'sets 4 in Direct Tuning Mode',
                    'name'        => '4-in-direct-mode'
                },
                '5',
                {
                    'description' => 'sets 5 in Direct Tuning Mode',
                    'name'        => '5-in-direct-mode'
                },
                '6',
                {
                    'description' => 'sets 6 in Direct Tuning Mode',
                    'name'        => '6-in-direct-mode'
                },
                '7',
                {
                    'description' => 'sets 7 in Direct Tuning Mode',
                    'name'        => '7-in-direct-mode'
                },
                '8',
                {
                    'description' => 'sets 8 in Direct Tuning Mode',
                    'name'        => '8-in-direct-mode'
                },
                '9',
                {
                    'description' => 'sets 9 in Direct Tuning Mode',
                    'name'        => '9-in-direct-mode'
                },
                'UP',
                {
                    'description' => 'sets Tuning Frequency Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Tuning Frequency Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Tuning Frequency',
                    'name'        => 'query'
                }
            }
        },
        'PRS',
        {
            'description' => 'Preset Command {Include Tuner Pack Model Only}',
            'name'        => 'preset',
            'values'      => {
                '{1,40}',
                {
                    'description' =>
                      'sets Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'no-1-40'
                },
                '{1,30}',
                {
                    'description' =>
                      'sets Preset No. 1 - 30 { In hexadecimal representation}',
                    'name' => 'no-1-30'
                },
                'UP',
                {
                    'description' => 'sets Preset No. Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Preset No. Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Preset No.',
                    'name'        => 'query'
                }
            }
        },
        'PRM',
        {
            'description' =>
              'Preset Memory Command {Include Tuner Pack Model Only}',
            'name'   => 'preset-memory',
            'values' => {
                '{1,40}',
                {
                    'description' =>
                      'sets Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'no-1-40'
                },
                '{1,30}',
                {
                    'description' =>
                      'sets Preset No. 1 - 30 { In hexadecimal representation}',
                    'name' => 'no-1-30'
                }
            }
        },
        'RDS',
        {
            'description' => 'RDS Information Command {RDS Model Only}',
            'name'        => 'rds-information',
            'values'      => {
                '00',
                {
                    'description' => 'Display RT Information',
                    'name'        => '00'
                },
                '01',
                {
                    'description' => 'Display PTY Information',
                    'name'        => '01'
                },
                '02',
                {
                    'description' => 'Display TP Information',
                    'name'        => '02'
                },
                'UP',
                {
                    'description' =>
                      'Display RDS Information Wrap-Around Change',
                    'name' => 'up'
                }
            }
        },
        'PTS',
        {
            'description' => 'PTY Scan Command {RDS Model Only}',
            'name'        => 'pty-scan',
            'values'      => {
                '{0,30}',
                {
                    'description' =>
'sets PTY No \u201c0 - 30\u201d { In hexadecimal representation}',
                    'name' => 'no-0-30'
                },
                'ENTER',
                {
                    'description' => 'Finish PTY Scan',
                    'name'        => 'enter'
                }
            }
        },
        'TPS',
        {
            'description' => 'TP Scan Command {RDS Model Only}',
            'name'        => 'tp-scan',
            'values'      => {
                '',
                {
                    'description' =>
                      'Start TP Scan {When Don\u2019t Have Parameter}',
                    'name' => 'None'
                },
                'ENTER',
                {
                    'description' => 'Finish TP Scan',
                    'name'        => 'enter'
                }
            }
        },
        'XCN',
        {
            'description' => 'XM Channel Name Info {XM Model Only}',
            'name'        => 'xm-channel-name-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' => 'XM Channel Name',
                    'name'        => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets XM Channel Name',
                    'name'        => 'query'
                }
            }
        },
        'XAT',
        {
            'description' => 'XM Artist Name Info {XM Model Only}',
            'name'        => 'xm-artist-name-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' => 'XM Artist Name',
                    'name'        => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets XM Artist Name',
                    'name'        => 'query'
                }
            }
        },
        'XTI',
        {
            'description' => 'XM Title Info {XM Model Only}',
            'name'        => 'xm-title-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' => 'XM Title',
                    'name'        => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets XM Title',
                    'name'        => 'query'
                }
            }
        },
        'XCH',
        {
            'description' => 'XM Channel Number Command {XM Model Only}',
            'name'        => 'xm-channel-number',
            'values'      => {
                '{0,597}',
                {
                    'description' => 'XM Channel Number  \u201c000 - 255\u201d',
                    'name'        => 'None'
                },
                'UP',
                {
                    'description' => 'sets XM Channel Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets XM Channel Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets XM Channel Number',
                    'name'        => 'query'
                }
            }
        },
        'XCT',
        {
            'description' => 'XM Category Command {XM Model Only}',
            'name'        => 'xm-category',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' => 'XM Category Info',
                    'name'        => 'None'
                },
                'UP',
                {
                    'description' => 'sets XM Category Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets XM Category Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets XM Category',
                    'name'        => 'query'
                }
            }
        },
        'SCN',
        {
            'description' => 'SIRIUS Channel Name Info {SIRIUS Model Only}',
            'name'        => 'sirius-channel-name-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' => 'SIRIUS Channel Name',
                    'name'        => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets SIRIUS Channel Name',
                    'name'        => 'query'
                }
            }
        },
        'SAT',
        {
            'description' => 'SIRIUS Artist Name Info {SIRIUS Model Only}',
            'name'        => 'sirius-artist-name-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' => 'SIRIUS Artist Name',
                    'name'        => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets SIRIUS Artist Name',
                    'name'        => 'query'
                }
            }
        },
        'STI',
        {
            'description' => 'SIRIUS Title Info {SIRIUS Model Only}',
            'name'        => 'sirius-title-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' => 'SIRIUS Title',
                    'name'        => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets SIRIUS Title',
                    'name'        => 'query'
                }
            }
        },
        'SCH',
        {
            'description' =>
              'SIRIUS Channel Number Command {SIRIUS Model Only}',
            'name'   => 'sirius-channel-number',
            'values' => {
                '{0,597}',
                {
                    'description' =>
                      'SIRIUS Channel Number  \u201c000 - 255\u201d',
                    'name' => 'None'
                },
                'UP',
                {
                    'description' => 'sets SIRIUS Channel Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets SIRIUS Channel Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets SIRIUS Channel Number',
                    'name'        => 'query'
                }
            }
        },
        'SCT',
        {
            'description' => 'SIRIUS Category Command {SIRIUS Model Only}',
            'name'        => 'sirius-category',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' => 'SIRIUS Category Info',
                    'name'        => 'None'
                },
                'UP',
                {
                    'description' => 'sets SIRIUS Category Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets SIRIUS Category Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets SIRIUS Category',
                    'name'        => 'query'
                }
            }
        },
        'SLK',
        {
            'description' => 'SIRIUS Parental Lock Command {SIRIUS Model Only}',
            'name'        => 'sirius-parental-lock',
            'values'      => {
                'nnnn',
                {
                    'description' => 'Lock Password {4Digits}',
                    'name'        => 'None'
                },
                'INPUT',
                {
                    'description' =>
                      'displays "Please input the Lock password"',
                    'name' => 'input'
                },
                'WRONG',
                {
                    'description' => 'displays "The Lock password is wrong"',
                    'name'        => 'wrong'
                }
            }
        },
        'HAT',
        {
            'description' => 'HD Radio Artist Name Info {HD Radio Model Only}',
            'name'        => 'hd-radio-artist-name-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' =>
                      'HD Radio Artist Name {variable-length, 64 digits max}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Artist Name',
                    'name'        => 'query'
                }
            }
        },
        'HCN',
        {
            'description' => 'HD Radio Channel Name Info {HD Radio Model Only}',
            'name'        => 'hd-radio-channel-name-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' =>
                      'HD Radio Channel Name {Station Name} {7 digits}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Channel Name',
                    'name'        => 'query'
                }
            }
        },
        'HTI',
        {
            'description' => 'HD Radio Title Info {HD Radio Model Only}',
            'name'        => 'hd-radio-title-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' =>
                      'HD Radio Title {variable-length, 64 digits max}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Title',
                    'name'        => 'query'
                }
            }
        },
        'HDS',
        {
            'description' => 'HD Radio Detail Info {HD Radio Model Only}',
            'name'        => 'hd-radio-detail-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' => 'HD Radio Title',
                    'name'        => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Title',
                    'name'        => 'query'
                }
            }
        },
        'HPR',
        {
            'description' =>
              'HD Radio Channel Program Command {HD Radio Model Only}',
            'name'   => 'hd-radio-channel-program',
            'values' => {
                '{1,8}',
                {
                    'description' => 'sets directly HD Radio Channel Program',
                    'name'        => 'directly'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Channel Program',
                    'name'        => 'query'
                }
            }
        },
        'HBL',
        {
            'description' =>
              'HD Radio Blend Mode Command {HD Radio Model Only}',
            'name'   => 'hd-radio-blend-mode',
            'values' => {
                '00',
                {
                    'description' => 'sets HD Radio Blend Mode "Auto"',
                    'name'        => 'auto'
                },
                '01',
                {
                    'description' => 'sets HD Radio Blend Mode "Analog"',
                    'name'        => 'analog'
                },
                'QSTN',
                {
                    'description' => 'gets the HD Radio Blend Mode Status',
                    'name'        => 'query'
                }
            }
        },
        'HTS',
        {
            'description' => 'HD Radio Tuner Status {HD Radio Model Only}',
            'name'        => 'hd-radio-tuner-status',
            'values'      => {
                'mmnnoo',
                {
                    'description' =>
'HD Radio Tuner Status {3 bytes}\nmm -> "00" not HD, "01" HD\nnn -> current Program "01"-"08"\noo -> receivable Program {8 bits are represented in hexadecimal notation. Each bit shows receivable or not.}',
                    'name' => 'mmnnoo'
                },
                'QSTN',
                {
                    'description' => 'gets the HD Radio Tuner Status',
                    'name'        => 'query'
                }
            }
        },
        'NTC',
        {
            'description' =>
'Network/USB Operation Command {Network Model Only after TX-NR905}',
            'name'   => 'net-usb',
            'values' => {
                'PLAY',
                {
                    'description' => 'PLAY KEY',
                    'name'        => 'play'
                },
                'STOP',
                { 'description' => 'STOP KEY', 'name' => 'stop' },
                'PAUSE',
                { 'description' => 'PAUSE KEY', 'name' => 'pause' },
                'TRUP',
                {
                    'description' => 'TRACK UP KEY',
                    'name'        => 'next'
                },
                'TRDN',
                {
                    'description' => 'TRACK DOWN KEY',
                    'name'        => 'previous'
                },
                'FF',
                {
                    'description' => 'FF KEY {CONTINUOUS*}',
                    'name'        => 'ff'
                },
                'REW',
                {
                    'description' => 'REW KEY {CONTINUOUS*}',
                    'name'        => 'rew'
                },
                'REPEAT',
                {
                    'description' => 'REPEAT KEY',
                    'name'        => 'repeat'
                },
                'RANDOM',
                {
                    'description' => 'RANDOM KEY',
                    'name'        => 'random'
                },
                'DISPLAY',
                {
                    'description' => 'DISPLAY KEY',
                    'name'        => 'display'
                },
                'ALBUM',
                { 'description' => 'ALBUM KEY', 'name' => 'album' },
                'ARTIST',
                {
                    'description' => 'ARTIST KEY',
                    'name'        => 'artist'
                },
                'GENRE',
                { 'description' => 'GENRE KEY', 'name' => 'genre' },
                'PLAYLIST',
                {
                    'description' => 'PLAYLIST KEY',
                    'name'        => 'playlist'
                },
                'RIGHT',
                { 'description' => 'RIGHT KEY', 'name' => 'right' },
                'LEFT',
                { 'description' => 'LEFT KEY', 'name' => 'left' },
                'UP',
                { 'description' => 'UP KEY', 'name' => 'up' },
                'DOWN',
                { 'description' => 'DOWN KEY', 'name' => 'down' },
                'SELECT',
                {
                    'description' => 'SELECT KEY',
                    'name'        => 'select'
                },
                '0',
                { 'description' => '0 KEY', 'name' => '0' },
                '1',
                { 'description' => '1 KEY', 'name' => '1' },
                '2',
                { 'description' => '2 KEY', 'name' => '2' },
                '3',
                { 'description' => '3 KEY', 'name' => '3' },
                '4',
                { 'description' => '4 KEY', 'name' => '4' },
                '5',
                { 'description' => '5 KEY', 'name' => '5' },
                '6',
                { 'description' => '6 KEY', 'name' => '6' },
                '7',
                { 'description' => '7 KEY', 'name' => '7' },
                '8',
                { 'description' => '8 KEY', 'name' => '8' },
                '9',
                { 'description' => '9 KEY', 'name' => '9' },
                'DELETE',
                {
                    'description' => 'DELETE KEY',
                    'name'        => 'delete'
                },
                'CAPS',
                { 'description' => 'CAPS KEY', 'name' => 'caps' },
                'LOCATION',
                {
                    'description' => 'LOCATION KEY',
                    'name'        => 'location'
                },
                'LANGUAGE',
                {
                    'description' => 'LANGUAGE KEY',
                    'name'        => 'language'
                },
                'SETUP',
                { 'description' => 'SETUP KEY', 'name' => 'setup' },
                'RETURN',
                {
                    'description' => 'RETURN KEY',
                    'name'        => 'return'
                },
                'CHUP',
                {
                    'description' => 'CH UP{for iRadio}',
                    'name'        => 'chup'
                },
                'CHDN',
                {
                    'description' => 'CH DOWN{for iRadio}',
                    'name'        => 'chdn'
                },
                'MENU',
                { 'description' => 'MENU', 'name' => 'menu' },
                'TOP',
                { 'description' => 'TOP MENU', 'name' => 'top' },
                'MODE',
                {
                    'description' => 'MODE{for iPod} STD<->EXT',
                    'name'        => 'mode'
                },
                'LIST',
                {
                    'description' => 'LIST <-> PLAYBACK',
                    'name'        => 'list'
                }
            }
        },
        'NAT',
        {
            'description' => 'NET/USB Artist Name Info',
            'name'        => 'net-usb-artist-name-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' =>
'NET/USB Artist Name {variable-length, 64 Unicode letters [UTF-8 encoded] max , for Network Control only}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Artist Name',
                    'name'        => 'query'
                }
            }
        },
        'NAL',
        {
            'description' => 'NET/USB Album Name Info',
            'name'        => 'net-usb-album-name-info',
            'values'      => {
                'nnnnnnn',
                {
                    'description' =>
'NET/USB Album Name {variable-length, 64 Unicode letters [UTF-8 encoded] max , for Network Control only}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Album Name',
                    'name'        => 'query'
                }
            }
        },
        'NTI',
        {
            'description' => 'NET/USB Title Name',
            'name'        => 'net-usb-title-name',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' =>
'NET/USB Title Name {variable-length, 64 Unicode letters [UTF-8 encoded] max , for Network Control only}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Title',
                    'name'        => 'query'
                }
            }
        },
        'NTM',
        {
            'description' => 'NET/USB Time Info',
            'name'        => 'net-usb-time-info',
            'values'      => {
                'mm:ss/mm:ss',
                {
                    'description' =>
                      'NET/USB Time Info {Elapsed time/Track Time Max 99:59}',
                    'name' => 'mm-ss-mm-ss'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Time Info',
                    'name'        => 'query'
                }
            }
        },
        'NTS',
        {
            'description' => 'NET/USB Time Seek',
            'name'        => 'net-usb-time-seek',
            'values'      => {
                'mm:ss',
                {
                    'description' =>
'mm: munites (00-99) ss: seconds (00-59). This command is only available when Time Seek is enable.',
                    'name' => 'mm-ss'
                },
            }
        },
        'NTR',
        {
            'description' => 'NET/USB Track Info',
            'name'        => 'net-usb-track-info',
            'values'      => {
                'cccc/tttt',
                {
                    'description' =>
                      'NET/USB Track Info {Current Track/Toral Track Max 9999}',
                    'name' => 'cccc-tttt'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Time Info',
                    'name'        => 'query'
                }
            }
        },
        'NST',
        {
            'description' => 'NET/USB Play Status',
            'name'        => 'net-usb-play-status',
            'values'      => {
                'prs',
                {
                    'description' =>
'NET/USB Play Status {3 letters}\np -> Play Status: "S": STOP, "P": Play, "p": Pause, "F": FF, "R": FR\nr -> Repeat Status: "-": Off, "R": All, "F": Folder, "1": Repeat 1,\ns -> Shuffle Status: "-": Off, "S": All , "A": Album, "F": Folder',
                    'name' => 'prs'
                },
                'QSTN',
                {
                    'description' => 'gets the Net/USB Status',
                    'name'        => 'query'
                }
            }
        },
        'NPR',
        {
            'description' => 'Internet Radio Preset Command',
            'name'        => 'internet-radio-preset',
            'values'      => {
                '{1,40}',
                {
                    'description' =>
                      'sets Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'no-1-40'
                },
                'SET',
                {
                    'description' => 'preset memory current station',
                    'name'        => 'set'
                }
            }
        },
        'NLS',
        {
            'description' => 'NET/USB List Info',
            'name'        => 'net-usb-list-info',
            'values'      => {
                'tlpnnnnnnnnnn',
                {
                    'description' =>
'NET/USB List Info\nt ->Information Type {A : ASCII letter, C : Cursor Info, U : Unicode letter}\nwhen t = A,\n  l ->Line Info {0-9 : 1st to 10th Line}\n  nnnnnnnnn:Listed data {variable-length, 64 ASCII letters max}\n    when AVR is not displayed NET/USB List{Ketboard,Menu,Popup\u2026}, "nnnnnnnnn" is "See TV".\n  p ->Property {- : no}\nwhen t = C,\n  l ->Cursor Position {0-9 : 1st to 10th Line, - : No Cursor}\n  p ->Update Type {P : Page Infomation Update { Page Clear or Disable List Info} , C : Cursor Position Update}\nwhen t = U, {for Network Control Only}\n  l ->Line Info {0-9 : 1st to 10th Line}\n  nnnnnnnnn:Listed data {variable-length, 64 Unicode letters [UTF-8 encoded] max}\n    when AVR is not displayed NET/USB List{Ketboard,Menu,Popup\u2026}, "nnnnnnnnn" is "See TV".\n  p ->Property {- : no}',
                    'name' => 'None'
                },
                'ti',
                {
                    'description' =>
'select the listed item {from Network Control Only}\n t -> Index Type {L : Line, I : Index}\nwhen t = L,\n  i -> Line number {0-9 : 1st to 10th Line [1 digit] }\nwhen t = I,\n  iiiii -> Index number {00001-99999 : 1st to 99999th Item [5 digits] }',
                    'name' => 'none'
                }
            },
        },
        'NLA',
        {
            'description' =>
'NET/USB List Info (All item, need processing XML data, for Network Control Only)',
            'name'   => 'net-usb-list-info-xml',
            'values' => {
                'tzzzzsurr<.....>',
                {
                    'description' => 't -> responce type \'X\' : XML
zzzz -> sequence number (0000-FFFF)
s -> status \'S\' : success, \'E\' : error
u -> UI type \'0\' : List, \'1\' : Menu, \'2\' : Playback, \'3\' : Popup, \'4\' : Keyboard, ""5"" : Menu List
rr -> reserved
<.....> : XML data ( [CR] and [LF] are removed )
 If s=\'S\',
 <?xml version=""1.0"" encoding=""UFT-8""?>
 <response status=""ok"">
   <items offset=""xxxx"" totalitems=""yyyy"" >
     <item icontype=""a"" title=""bbb…bbb"" />
     …
     <item icontype=""a"" title=""bbb…bbb"" />
   </Items>
 </response>
 If s=\'E\',
 <?xml version=""1.0"" encoding=""UFT-8""?>
 <response status=""fail"">
   <error code=""[error code]"" message=""[error message]"" />
 </response>
xxxx : index of 1st item (0000-FFFF : 1st to 65536th Item [4 HEX digits] )
yyyy : number of items (0000-FFFF : 1 to 65536 Items [4 HEX digits] )
a: Icon Type (for Spotify)
 \'0\' : Playing, \'1\' : Pause, \'2\' : FF, \'3\' : FR
 \'A\' : Artist, \'B\' : Album, \'F\' : Folder, \'G\' : Program, \'M\' : Music, \'N\' : Server, \'P\' : Playlist, \'S\' : Search, \'T\' : Track
 \'a\' : Account, \'b\' : Playlist-C, \'c\' : Starred, \'d\' : Unstarred, \'e\' : What\'s New
bbb...bbb : Title',
                    'name' => 'None'
                },
                'tzzzzsurr<.....>',
                {
                    'description' => 't -> responce type \'X\' : XML
zzzz -> sequence number (0000-FFFF)
s -> status \'S\' : success, \'E\' : error
u -> UI type \'0\' : List, \'1\' : Menu, \'2\' : Playback, \'3\' : Popup, \'4\' : Keyboard, ""5"" : Menu List
rr -> reserved
<.....> : XML data ( [CR] and [LF] are removed )
 If s=\'S\',
 <?xml version=""1.0"" encoding=""UFT-8""?>
 <response status=""ok"">
   <items offset=""xxxx"" totalitems=""yyyy"" >
     <item iconid=""aa"" title=""bbb…bbb"" />
     …
     <item iconid=""aa"" title=""bbb…bbb"" />
   </Items>
 </response>
 If s=\'E\',
 <?xml version=""1.0"" encoding=""UFT-8""?>
 <response status=""fail"">
   <error code=""[error code]"" message=""[error message]"" />
 </response>
xxxx : index of 1st item (0000-FFFF : 1st to 65536th Item [4 HEX digits] )
yyyy : number of items (0000-FFFF : 1 to 65536 Items [4 HEX digits] )
aa : Icon ID
 \'29\' : Folder, \'2A\' : Folder X, \'2B\' : Server, \'2C\' : Server X, \'2D\' : Title, \'2E\' : Title X,
 \'2F\' : Program, \'31\' : USB, \'36\' : Play, \'37\' : MultiAccount,
 for Spotify
 \'38\' : Account, \'39\' : Album, \'3A\' : Playlist, \'3B\' : Playlist-C, \'3C\' : starred,
 \'3D\' : What\'sNew, \'3E\' : Artist, \'3F\' : Track, \'40\' : unstarred, \'41\' : Play, \'43\' : Search, \'44\' : Folder
 for AUPEO!
 \'42\' : Program
bbb...bbb : Title',
                    'name' => 'None'
                },
                'Lzzzzllxxxxyyyy',
                {
                    'description' =>
'specifiy to get the listed data (from Network Control Only)
zzzz -> sequence number (0000-FFFF)
ll -> number of layer (00-FF)
xxxx -> index of start item (0000-FFFF : 1st to 65536th Item [4 HEX digits] )
yyyy -> number of items (0000-FFFF : 1 to 65536 Items [4 HEX digits] )',
                    'name' => 'none'
                },
                'Izzzzllxxxx----',
                {
                    'description' =>
                      'select the listed item (from Network Control Only)
zzzz -> sequence number (0000-FFFF)
ll -> number of layer (00-FF)
xxxx -> index number (0000-FFFF : 1st to 65536th Item [4 HEX digits] )
---- -> not used',
                    'name' => 'none'
                },
            },
        },
        'NLT',
        {
            'description' => 'NET/USB List Title Info',
            'name'        => 'net-usb-list-title-info',
            'values'      => {
                'xxuycccciiiillrraabbssnnn...nnn',
                {
                    'description' => 'NET/USB List Title Info
xx : Service Type
 00 : DLNA, 01 : Favorite, 02 : vTuner, 03 : SiriusXM, 04 : Pandora, 05 : Rhapsody, 06 : Last.fm,
 07 : Napster, 08 : Slacker, 09 : Mediafly, 0A : Spotify, 0B : AUPEO!, 0C : radiko, 0D : e-onkyo,
 0E : TuneIn Radio, 0F : MP3tunes, 10 : Simfy, 11:Home Media
 F0 : USB Front, F1 : USB Rear, F2 : Internet Radio, F3 : NET, FF : None
u : UI Type
 0 : List, 1 : Menu, 2 : Playback, 3 : Popup, 4 : Keyboard, \"\"5\"\" : Menu List
y : Layer Info
 0 : NET TOP, 1 : Service Top,DLNA/USB/iPod Top, 2 : under 2nd Layer
cccc : Current Cursor Position (HEX 4 letters)
iiii : Number of List Items (HEX 4 letters)
ll : Number of Layer(HEX 2 letters)
rr : Reserved (2 leters)
aa : Icon on Left of Title Bar
 00 : Internet Radio, 01 : Server, 02 : USB, 03 : iPod, 04 : DLNA, 05 : WiFi, 06 : Favorite
 10 : Account(Spotify), 11 : Album(Spotify), 12 : Playlist(Spotify), 13 : Playlist-C(Spotify)
 14 : Starred(Spotify), 15 : What\'s New(Spotify), 16 : Track(Spotify), 17 : Artist(Spotify)
 18 : Play(Spotify), 19 : Search(Spotify), 1A : Folder(Spotify)
 FF : None
bb : Icon on Right of Title Bar
 00 : DLNA, 01 : Favorite, 02 : vTuner, 03 : SiriusXM, 04 : Pandora, 05 : Rhapsody, 06 : Last.fm,
 07 : Napster, 08 : Slacker, 09 : Mediafly, 0A : Spotify, 0B : AUPEO!, 0C : radiko, 0D : e-onkyo,
 0E : TuneIn Radio, 0F : MP3tunes, 10 : Simfy, 11:Home Media
 FF : None
ss : Status Info
 00 : None, 01 : Connecting, 02 : Acquiring License, 03 : Buffering
 04 : Cannot Play, 05 : Searching, 06 : Profile update, 07 : Operation disabled
 08 : Server Start-up, 09 : Song rated as Favorite, 0A : Song banned from station,
 0B : Authentication Failed, 0C : Spotify Paused(max 1 device), 0D : Track Not Available, 0E : Cannot Skip
nnn...nnn : Character of Title Bar (variable-length, 64 Unicode letters [UTF-8 encoded] max)',
                    'name' => 'None'
                },
            }
        },
        'NDS',
        {
            'description' => 'NET Connection/USB Device Status',
            'name'        => 'net-usb-device-status',
            'values'      => {
                'nfr',
                {
                    'description' =>
                      'NET Connection/USB Device Status (3 letters)
n -> NET Connection status: \"-\": no connection, \"E\": Ether, \"W\": Wireless
f -> Front USB(USB1) Device Status: \"-\": no device, \"i\": iPod/iPhone, 
      \"M\": Memory/NAS, \"W\": Wireless Adaptor, \"B\": Bluetooth Adaptor,
      \"G\": Google USB, \"x\": disable
r -> Rear USB(USB2) Device Status: \"-\": no device, \"i\": iPod/iPhone, 
      \"M\": Memory/NAS, \"W\": Wireless Adaptor, \"B\": Bluetooth Adaptor, 
      \"G\": Google USB, \"x\": disable',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets the Net/USB Status',
                    'name'        => 'query'
                },
            }
        },
        'NMS',
        {
            'description' => 'NET/USB Menu Status',
            'name'        => 'net-usb-menu-status',
            'values'      => {
                'maabbstii',
                {
                    'description' => 'NET/USB Menu Status (7 letters)
m -> Track Menu: \"\"M\"\": Menu is enable, \"\"x\"\": Menu is disable
aa -> F1 button icon (Positive Feed or Mark/Unmark)
bb -> F2 button icon (Negative Feed)
 aa or bb : \"\"xx\"\":disable, \"\"01\"\":Like, \"\"02\"\":don\'t like, \"\"03\"\":Love, \"\"04\"\":Ban,
                  \"\"05\"\":episode, \"\"06\"\":ratings, \"\"07\"\":Ban(black), \"\"08\"\":Ban(white),
                  \"\"09\"\":Favorite(black), \"\"0A\"\":Favorite(white), \"\"0B\"\":Favorite(yellow)
s -> Time Seek \"\"S\"\": Time Seek is enable \"\"x\"\": Time Seek is disable
t -> Time Display \"\"1\"\": Elapsed Time/Total Time, \"\"2\"\": Elapsed Time, \"\"x\"\": disable
ii-> Service icon
 ii : \"\"00\"\":DLNA, \"\"01\"\":My Favorite, \"\"02\"\":vTuner, \"\"03\"\":SiriusXM, \"\"04\"\":Pandora,
      \"\"05\"\":Rhapsody, \"\"06\"\":Last.fm, \"\"08\"\":Slacker, \"\"0A\"\":Spotify, \"\"0B\"\":AUPEO!,
      \"\"0C\"\":radiko, \"\"0D\"\":e-onkyo, \"\"0E\"\":TuneIn, \"\"0F\"\":MP3tunes, \"\"10\"\":Simfy,
      \"\"11\"\":Home Media, \"\"F0\"\": USB Front, \"\"F1: USB Rear, \"\"F2\"\":Internet Radio
      \"\"F3\"\":NET, \"\"F4\"\":Bluetooth',
                    'name' => 'None'
                },
            }
        },
        'NJA',
        {
            'description' =>
'NET/USB Jacket Art {When Jacket Art is available and Output for Network Control Only}',
            'name'   => 'net-usb-jacket-art',
            'values' => {
                'tp{xx}{xx}{xx}{xx}{xx}{xx}',
                {
                    'description' =>
'NET/USB Jacket Art/Album Art Data\nt-> Image type 0:BMP,1:JPEG\np-> Packet flag 0:Start, 1:Next, 2:End\nxxxxxxxxxxxxxx -> Jacket/Album Art Data {valiable length, 1024 ASCII HEX letters max}',
                    'name' => 'tp-xx-xx-xx-xx-xx-xx'
                },

                'DIS',
                {
                    'description' => 'sets Jacket Art disable',
                    'name'        => 'off'
                },

                'ENA',
                {
                    'description' => 'sets Jacket Art enable',
                    'name'        => 'on'
                },

                'BMP',
                {
                    'description' => 'sets Jacket Art enable and type BMP',
                    'name'        => 'bmp'
                },

                'LINK',
                {
                    'description' => 'sets Jacket Art enable and type LINK',
                    'name'        => 'link'
                },

                'UP',
                {
                    'description' => 'sets Jacket Art Wrap-Around up',
                    'name'        => 'up'
                },

                'QSTN',
                {
                    'description' => 'gets Jacket Art enable/disable',
                    'name'        => 'query'
                }
            }
        },
        'NSB',
        {
            'description' =>
'Network Standby Settings (for Network Control Only and Available in AVR is PowerOn)',
            'name'   => 'network-standby',
            'values' => {
                'OFF',
                {
                    'description' => 'sets Network Standby is Off',
                    'name'        => 'off'
                },
                'ON',
                {
                    'description' => 'sets Network Standby is On',
                    'name'        => 'on'
                },
                'QSTN',
                {
                    'description' => 'gets Network Standby Setting',
                    'name'        => 'query'
                },
            }
        },
        'NSV',
        {
            'description' => 'NET Service{for Network Control Only}',
            'name'        => 'net-service',
            'values'      => {
                '00',
                {
                    'description' => 'Music Server (DLNA)',
                    'name'        => 'DLNA'
                },
                '01',
                {
                    'description' => 'My Favorites',
                    'name'        => [ 'My_Favorites', 'Favorite' ]
                },
                '02',
                {
                    'description' => 'vTuner',
                    'name'        => 'vTuner'
                },
                '03',
                {
                    'description' => 'SiriusXM Internet Radio',
                    'name'        => [ 'SiriusXM_Internet_Radio', 'SIRIUS' ]
                },
                '04',
                {
                    'description' => 'Pandora Internet Radio',
                    'name'        => [ 'Pandora_Internet_Radio', 'Pandora' ]
                },
                '05',
                {
                    'description' => 'Rhapsody',
                    'name'        => 'Rhapsody'
                },
                '06',
                {
                    'description' => 'Last.fm Internet Radio',
                    'name'        => [ 'Last.fm_Internet_Radio', 'Last.fm' ]
                },
                '07',
                {
                    'description' => 'Napster',
                    'name'        => 'Napster'
                },
                '08',
                {
                    'description' => 'Slacker Personal Radio',
                    'name'        => [ 'Slacker_Personal_Radio', 'Slacker' ]
                },
                '09',
                {
                    'description' => 'Mediafly',
                    'name'        => 'Mediafly'
                },
                '0A',
                {
                    'description' => 'Spotify',
                    'name'        => 'Spotify'
                },
                '0B',
                {
                    'description' => 'AUPEO! PERSONAL RADIO',
                    'name'        => [ 'AUPEO!_PERSONAL_RADIO', 'AUPEO!' ]
                },
                '0C',
                {
                    'description' => 'radiko.jp',
                    'name'        => [ 'radiko.jp', 'radiko' ]
                },
                '0D',
                {
                    'description' => 'e-onkyo music',
                    'name'        => [ 'e-onkyo_music', 'e-onkyo' ]
                },
                '0E',
                {
                    'description' => 'TuneIn',
                    'name'        => 'TuneIn'
                },
                '0F',
                {
                    'description' => 'MP3tunes',
                    'name'        => 'MP3tunes'
                },
                '10',
                {
                    'description' => 'simfy',
                    'name'        => 'simfy'
                },
                '11',
                {
                    'description' => 'Home Media',
                    'name'        => 'Home_Media'
                },
            }
        },
        'NKY',
        {
            'description' => 'NET Keyboard{for Network Control Only}',
            'name'        => 'net-keyboard',
            'values'      => {
                'll',
                {
                    'description' =>
'waiting Keyboard Input\nll -> category\n 00: Off { Exit Keyboard Input }\n 01: User Name\n 02: Password\n 03: Artist Name\n 04: Album Name\n 05: Song Name\n 06: Station Name\n 07: Tag Name\n 08: Artist or Song\n 09: Episode Name\n 0A: Pin Code {some digit Number [0-9}\n 0B: User Name {available ISO 8859-1 character set}\n 0C: Password {available ISO 8859-1 character set}',
                    'name' => 'll'
                },
                'nnnnnnnnn',
                {
                    'description' =>
'set Keyboard Input letter\n"nnnnnnnn" is variable-length, 128 Unicode letters [UTF-8 encoded] max',
                    'name' => 'None'
                }
            }
        },
        'NPU',
        {
            'description' => 'NET Popup Message{for Network Control Only}',
            'name'        => 'net-popup-message',
            'values'      => {
                'xaaa\u2026aaaybbb\u2026bbb',
                {
                    'description' =>
"x -> Popup Display Type\n 'T' => Popup text is top\n 'B' => Popup text is bottom\n 'L' => Popup text is list format\n\naaa...aaa -> Popup Title, Massage\n when x = 'T' or 'B'\n    Top Title [0x00] Popup Title [0x00] Popup Message [0x00]\n    {valiable-length Unicode letter [UTF-8 encoded] }\n\n when x = 'L'\n    Top Title [0x00] Item Title 1 [0x00] Item Parameter 1 [0x00] ... [0x00] Item Title 6 [0x00] Item Parameter 6 [0x00]\n    {valiable-length Unicode letter [UTF-8 encoded] }\n\ny -> Cursor Position on button\n '0' : Button is not Displayed\n '1' : Cursor is on the button 1\n '2' : Cursor is on the button 2\n\nbbb...bbb -> Text of Button\n    Text of Button 1 [0x00] Text of Button 2 [0x00]\n    {valiable-length Unicode letter [UTF-8 encoded] }",
                    'name' => 'None'
                }
            }
        },
        'NMD',
        {
            'description' => 'iPod Mode Change {with USB Connection Only}',
            'name'        => 'ipod-mode-change',
            'values'      => {
                'STD',
                {
                    'description' => 'Standerd Mode',
                    'name'        => 'std'
                },
                'EXT',
                {
                    'description' => 'Extend Mode{If available}',
                    'name'        => 'ext'
                },
                'VDC',
                {
                    'description' => 'Video Contents in Extended Mode',
                    'name'        => 'vdc'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Mode Status',
                    'name'        => 'query'
                }
            }
        },
        'CCD',
        {
            'description' => 'CD Player Operation Command',
            'name'        => 'cd-player',
            'values'      => {
                'POWER',
                {
                    'description' => 'POWER ON/OFF',
                    'name'        => 'power'
                },
                'TRACK',
                { 'description' => 'TRACK+', 'name' => 'track' },
                'PLAY',
                { 'description' => 'PLAY', 'name' => 'play' },
                'STOP',
                { 'description' => 'STOP', 'name' => 'stop' },
                'PAUSE',
                { 'description' => 'PAUSE', 'name' => 'pause' },
                'SKIP.F',
                { 'description' => '>>I', 'name' => 'skip-f' },
                'SKIP.R',
                { 'description' => 'I<<', 'name' => 'skip-r' },
                'MEMORY',
                { 'description' => 'MEMORY', 'name' => 'memory' },
                'CLEAR',
                { 'description' => 'CLEAR', 'name' => 'clear' },
                'REPEAT',
                { 'description' => 'REPEAT', 'name' => 'repeat' },
                'RANDOM',
                { 'description' => 'RANDOM', 'name' => 'random' },
                'DISP',
                { 'description' => 'DISPLAY', 'name' => 'disp' },
                'D.MODE',
                { 'description' => 'D.MODE', 'name' => 'd-mode' },
                'FF',
                { 'description' => 'FF >>', 'name' => 'ff' },
                'REW',
                { 'description' => 'REW <<', 'name' => 'rew' },
                'OP/CL',
                {
                    'description' => 'OPEN/CLOSE',
                    'name'        => 'op-cl'
                },
                '1',
                { 'description' => '1.0', 'name' => '1' },
                '2',
                { 'description' => '2.0', 'name' => '2' },
                '3',
                { 'description' => '3.0', 'name' => '3' },
                '4',
                { 'description' => '4.0', 'name' => '4' },
                '5',
                { 'description' => '5.0', 'name' => '5' },
                '6',
                { 'description' => '6.0', 'name' => '6' },
                '7',
                { 'description' => '7.0', 'name' => '7' },
                '8',
                { 'description' => '8.0', 'name' => '8' },
                '9',
                { 'description' => '9.0', 'name' => '9' },
                '0',
                { 'description' => '0.0', 'name' => '0' },
                '10',
                { 'description' => '10.0', 'name' => '10' },
                '+10',
                { 'description' => '+10', 'name' => '10' },
                'D.SKIP',
                { 'description' => 'DISC +', 'name' => 'd-skip' },
                'DISC.F',
                { 'description' => 'DISC +', 'name' => 'disc-f' },
                'DISC.R',
                { 'description' => 'DISC -', 'name' => 'disc-r' },
                'DISC1',
                { 'description' => 'DISC1', 'name' => 'disc1' },
                'DISC2',
                { 'description' => 'DISC2', 'name' => 'disc2' },
                'DISC3',
                { 'description' => 'DISC3', 'name' => 'disc3' },
                'DISC4',
                { 'description' => 'DISC4', 'name' => 'disc4' },
                'DISC5',
                { 'description' => 'DISC5', 'name' => 'disc5' },
                'DISC6',
                { 'description' => 'DISC6', 'name' => 'disc6' },
                'STBY',
                { 'description' => 'STANDBY', 'name' => 'stby' },
                'PON',
                { 'description' => 'POWER ON', 'name' => 'pon' }
            }
        },
        'CT1',
        {
            'description' => 'TAPE1{A} Operation Command',
            'name'        => 'tape1-a',
            'values'      => {
                'PLAY.F',
                {
                    'description' => 'PLAY >',
                    'name'        => 'play-f'
                },
                'PLAY.R',
                { 'description' => 'PLAY <', 'name' => 'play-r' },
                'STOP',
                { 'description' => 'STOP', 'name' => 'stop' },
                'RC/PAU',
                {
                    'description' => 'REC/PAUSE',
                    'name'        => 'rc-pau'
                },
                'FF',
                { 'description' => 'FF >>', 'name' => 'ff' },
                'REW',
                { 'description' => 'REW <<', 'name' => 'rew' }
            }
        },
        'CT2',
        {
            'description' => 'TAPE2{B} Operation Command',
            'name'        => 'tape2-b',
            'values'      => {
                'PLAY.F',
                {
                    'description' => 'PLAY >',
                    'name'        => 'play-f'
                },
                'PLAY.R',
                { 'description' => 'PLAY <', 'name' => 'play-r' },
                'STOP',
                { 'description' => 'STOP', 'name' => 'stop' },
                'RC/PAU',
                {
                    'description' => 'REC/PAUSE',
                    'name'        => 'rc-pau'
                },
                'FF',
                { 'description' => 'FF >>', 'name' => 'ff' },
                'REW',
                { 'description' => 'REW <<', 'name' => 'rew' },
                'OP/CL',
                {
                    'description' => 'OPEN/CLOSE',
                    'name'        => 'op-cl'
                },
                'SKIP.F',
                { 'description' => '>>I', 'name' => 'skip-f' },
                'SKIP.R',
                { 'description' => 'I<<', 'name' => 'skip-r' },
                'REC',
                { 'description' => 'REC', 'name' => 'rec' }
            }
        },
        'CEC' => {
            'description' => 'HDMI CEC',
            'name'        => 'hdmi-cec',
            'values'      => {
                '00',
                {
                    'description' => 'sets off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets on',
                    'name'        => 'on'
                },
                'UP',
                {
                    'description' => 'sets HDMI CEC Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets HDMI CEC',
                    'name'        => 'query'
                },
            }
        },
        'CEQ',
        {
            'description' => 'Graphics Equalizer Operation Command',
            'name'        => 'graphics-equalizer',
            'values'      => {
                'POWER',
                {
                    'description' => 'POWER ON/OFF',
                    'name'        => 'power'
                },
                'PRESET',
                { 'description' => 'PRESET', 'name' => 'preset' }
            }
        },
        'CDT',
        {
            'description' => 'DAT Recorder Operation Command',
            'name'        => 'dat-recorder',
            'values'      => {
                'PLAY',
                { 'description' => 'PLAY', 'name' => 'play' },
                'RC/PAU',
                {
                    'description' => 'REC/PAUSE',
                    'name'        => 'rc-pau'
                },
                'STOP',
                { 'description' => 'STOP', 'name' => 'stop' },
                'SKIP.F',
                { 'description' => '>>I', 'name' => 'skip-f' },
                'SKIP.R',
                { 'description' => 'I<<', 'name' => 'skip-r' },
                'FF',
                { 'description' => 'FF >>', 'name' => 'ff' },
                'REW',
                { 'description' => 'REW <<', 'name' => 'rew' }
            }
        },
        'CDV',
        {
            'description' =>
              'DVD Player Operation Command {via RIHD only after TX-NR509}',
            'name'   => 'dvd-player',
            'values' => {
                'POWER',
                {
                    'description' => 'POWER ON/OFF',
                    'name'        => 'power'
                },
                'PWRON',
                { 'description' => 'POWER ON', 'name' => 'pwron' },
                'PWROFF',
                {
                    'description' => 'POWER OFF',
                    'name'        => 'pwroff'
                },
                'PLAY',
                { 'description' => 'PLAY', 'name' => 'play' },
                'STOP',
                { 'description' => 'STOP', 'name' => 'stop' },
                'SKIP.F',
                { 'description' => '>>I', 'name' => 'skip-f' },
                'SKIP.R',
                { 'description' => 'I<<', 'name' => 'skip-r' },
                'FF',
                { 'description' => 'FF >>', 'name' => 'ff' },
                'REW',
                { 'description' => 'REW <<', 'name' => 'rew' },
                'PAUSE',
                { 'description' => 'PAUSE', 'name' => 'pause' },
                'LASTPLAY',
                {
                    'description' => 'LAST PLAY',
                    'name'        => 'lastplay'
                },
                'SUBTON/OFF',
                {
                    'description' => 'SUBTITLE ON/OFF',
                    'name'        => 'subton-off'
                },
                'SUBTITLE',
                {
                    'description' => 'SUBTITLE',
                    'name'        => 'subtitle'
                },
                'SETUP',
                { 'description' => 'SETUP', 'name' => 'setup' },
                'TOPMENU',
                { 'description' => 'TOPMENU', 'name' => 'topmenu' },
                'MENU',
                { 'description' => 'MENU', 'name' => 'menu' },
                'UP',
                { 'description' => 'UP', 'name' => 'up' },
                'DOWN',
                { 'description' => 'DOWN', 'name' => 'down' },
                'LEFT',
                { 'description' => 'LEFT', 'name' => 'left' },
                'RIGHT',
                { 'description' => 'RIGHT', 'name' => 'right' },
                'ENTER',
                { 'description' => 'ENTER', 'name' => 'enter' },
                'RETURN',
                { 'description' => 'RETURN', 'name' => 'return' },
                'DISC.F',
                { 'description' => 'DISC +', 'name' => 'disc-f' },
                'DISC.R',
                { 'description' => 'DISC -', 'name' => 'disc-r' },
                'AUDIO',
                { 'description' => 'AUDIO', 'name' => 'audio' },
                'RANDOM',
                { 'description' => 'RANDOM', 'name' => 'random' },
                'OP/CL',
                {
                    'description' => 'OPEN/CLOSE',
                    'name'        => 'op-cl'
                },
                'ANGLE',
                { 'description' => 'ANGLE', 'name' => 'angle' },
                '1',
                { 'description' => '1.0', 'name' => '1' },
                '2',
                { 'description' => '2.0', 'name' => '2' },
                '3',
                { 'description' => '3.0', 'name' => '3' },
                '4',
                { 'description' => '4.0', 'name' => '4' },
                '5',
                { 'description' => '5.0', 'name' => '5' },
                '6',
                { 'description' => '6.0', 'name' => '6' },
                '7',
                { 'description' => '7.0', 'name' => '7' },
                '8',
                { 'description' => '8.0', 'name' => '8' },
                '9',
                { 'description' => '9.0', 'name' => '9' },
                '10',
                { 'description' => '10.0', 'name' => '10' },
                '0',
                { 'description' => '0.0', 'name' => '0' },
                'SEARCH',
                { 'description' => 'SEARCH', 'name' => 'search' },
                'DISP',
                { 'description' => 'DISPLAY', 'name' => 'disp' },
                'REPEAT',
                { 'description' => 'REPEAT', 'name' => 'repeat' },
                'MEMORY',
                { 'description' => 'MEMORY', 'name' => 'memory' },
                'CLEAR',
                { 'description' => 'CLEAR', 'name' => 'clear' },
                'ABR',
                { 'description' => 'A-B REPEAT', 'name' => 'abr' },
                'STEP.F',
                { 'description' => 'STEP', 'name' => 'step-f' },
                'STEP.R',
                {
                    'description' => 'STEP BACK',
                    'name'        => 'step-r'
                },
                'SLOW.F',
                { 'description' => 'SLOW', 'name' => 'slow-f' },
                'SLOW.R',
                {
                    'description' => 'SLOW BACK',
                    'name'        => 'slow-r'
                },
                'ZOOMTG',
                { 'description' => 'ZOOM', 'name' => 'zoomtg' },
                'ZOOMUP',
                { 'description' => 'ZOOM UP', 'name' => 'zoomup' },
                'ZOOMDN',
                {
                    'description' => 'ZOOM DOWN',
                    'name'        => 'zoomdn'
                },
                'PROGRE',
                {
                    'description' => 'PROGRESSIVE',
                    'name'        => 'progre'
                },
                'VDOFF',
                {
                    'description' => 'VIDEO ON/OFF',
                    'name'        => 'vdoff'
                },
                'CONMEM',
                {
                    'description' => 'CONDITION MEMORY',
                    'name'        => 'conmem'
                },
                'FUNMEM',
                {
                    'description' => 'FUNCTION MEMORY',
                    'name'        => 'funmem'
                },
                'DISC1',
                { 'description' => 'DISC1', 'name' => 'disc1' },
                'DISC2',
                { 'description' => 'DISC2', 'name' => 'disc2' },
                'DISC3',
                { 'description' => 'DISC3', 'name' => 'disc3' },
                'DISC4',
                { 'description' => 'DISC4', 'name' => 'disc4' },
                'DISC5',
                { 'description' => 'DISC5', 'name' => 'disc5' },
                'DISC6',
                { 'description' => 'DISC6', 'name' => 'disc6' },
                'FOLDUP',
                {
                    'description' => 'FOLDER UP',
                    'name'        => 'foldup'
                },
                'FOLDDN',
                {
                    'description' => 'FOLDER DOWN',
                    'name'        => 'folddn'
                },
                'P.MODE',
                {
                    'description' => 'PLAY MODE',
                    'name'        => 'p-mode'
                },
                'ASCTG',
                {
                    'description' => 'ASPECT{Toggle}',
                    'name'        => 'asctg'
                },
                'CDPCD',
                {
                    'description' => 'CD CHAIN REPEAT',
                    'name'        => 'cdpcd'
                },
                'MSPUP',
                {
                    'description' => 'MULTI SPEED UP',
                    'name'        => 'mspup'
                },
                'MSPDN',
                {
                    'description' => 'MULTI SPEED DOWN',
                    'name'        => 'mspdn'
                },
                'PCT',
                {
                    'description' => 'PICTURE CONTROL',
                    'name'        => 'pct'
                },
                'RSCTG',
                {
                    'description' => 'RESOLUTION{Toggle}',
                    'name'        => 'rsctg'
                },
                'INIT',
                {
                    'description' => 'Return to Factory Settings',
                    'name'        => 'init'
                }
            }
        },
        'CMD',
        {
            'description' => 'MD Recorder Operation Command',
            'name'        => 'md-recorder',
            'values'      => {
                'POWER',
                {
                    'description' => 'POWER ON/OFF',
                    'name'        => 'power'
                },
                'PLAY',
                { 'description' => 'PLAY', 'name' => 'play' },
                'STOP',
                { 'description' => 'STOP', 'name' => 'stop' },
                'FF',
                { 'description' => 'FF >>', 'name' => 'ff' },
                'REW',
                { 'description' => 'REW <<', 'name' => 'rew' },
                'P.MODE',
                {
                    'description' => 'PLAY MODE',
                    'name'        => 'p-mode'
                },
                'SKIP.F',
                { 'description' => '>>I', 'name' => 'skip-f' },
                'SKIP.R',
                { 'description' => 'I<<', 'name' => 'skip-r' },
                'PAUSE',
                { 'description' => 'PAUSE', 'name' => 'pause' },
                'REC',
                { 'description' => 'REC', 'name' => 'rec' },
                'MEMORY',
                { 'description' => 'MEMORY', 'name' => 'memory' },
                'DISP',
                { 'description' => 'DISPLAY', 'name' => 'disp' },
                'SCROLL',
                { 'description' => 'SCROLL', 'name' => 'scroll' },
                'M.SCAN',
                {
                    'description' => 'MUSIC SCAN',
                    'name'        => 'm-scan'
                },
                'CLEAR',
                { 'description' => 'CLEAR', 'name' => 'clear' },
                'RANDOM',
                { 'description' => 'RANDOM', 'name' => 'random' },
                'REPEAT',
                { 'description' => 'REPEAT', 'name' => 'repeat' },
                'ENTER',
                { 'description' => 'ENTER', 'name' => 'enter' },
                'EJECT',
                { 'description' => 'EJECT', 'name' => 'eject' },
                '1',
                { 'description' => '1.0', 'name' => '1' },
                '2',
                { 'description' => '2.0', 'name' => '2' },
                '3',
                { 'description' => '3.0', 'name' => '3' },
                '4',
                { 'description' => '4.0', 'name' => '4' },
                '5',
                { 'description' => '5.0', 'name' => '5' },
                '6',
                { 'description' => '6.0', 'name' => '6' },
                '7',
                { 'description' => '7.0', 'name' => '7' },
                '8',
                { 'description' => '8.0', 'name' => '8' },
                '9',
                { 'description' => '9.0', 'name' => '9' },
                '10/0',
                { 'description' => '10/0', 'name' => '10-0' },
                'nn/nnn',
                { 'description' => '--/---', 'name' => 'None' },
                'NAME',
                { 'description' => 'NAME', 'name' => 'name' },
                'GROUP',
                { 'description' => 'GROUP', 'name' => 'group' },
                'STBY',
                { 'description' => 'STANDBY', 'name' => 'stby' }
            }
        },
        'CCR',
        {
            'description' => 'CD Recorder Operation Command',
            'name'        => 'cd-recorder',
            'values'      => {
                'POWER',
                {
                    'description' => 'POWER ON/OFF',
                    'name'        => 'power'
                },
                'P.MODE',
                {
                    'description' => 'PLAY MODE',
                    'name'        => 'p-mode'
                },
                'PLAY',
                { 'description' => 'PLAY', 'name' => 'play' },
                'STOP',
                { 'description' => 'STOP', 'name' => 'stop' },
                'SKIP.F',
                { 'description' => '>>I', 'name' => 'skip-f' },
                'SKIP.R',
                { 'description' => 'I<<', 'name' => 'skip-r' },
                'PAUSE',
                { 'description' => 'PAUSE', 'name' => 'pause' },
                'REC',
                { 'description' => 'REC', 'name' => 'rec' },
                'CLEAR',
                { 'description' => 'CLEAR', 'name' => 'clear' },
                'REPEAT',
                { 'description' => 'REPEAT', 'name' => 'repeat' },
                '1',
                { 'description' => '1.0', 'name' => '1' },
                '2',
                { 'description' => '2.0', 'name' => '2' },
                '3',
                { 'description' => '3.0', 'name' => '3' },
                '4',
                { 'description' => '4.0', 'name' => '4' },
                '5',
                { 'description' => '5.0', 'name' => '5' },
                '6',
                { 'description' => '6.0', 'name' => '6' },
                '7',
                { 'description' => '7.0', 'name' => '7' },
                '8',
                { 'description' => '8.0', 'name' => '8' },
                '9',
                { 'description' => '9.0', 'name' => '9' },
                '10/0',
                { 'description' => '10/0', 'name' => '10-0' },
                'nn/nnn',
                { 'description' => '--/---', 'name' => 'None' },
                'SCROLL',
                { 'description' => 'SCROLL', 'name' => 'scroll' },
                'OP/CL',
                {
                    'description' => 'OPEN/CLOSE',
                    'name'        => 'op-cl'
                },
                'DISP',
                { 'description' => 'DISPLAY', 'name' => 'disp' },
                'RANDOM',
                { 'description' => 'RANDOM', 'name' => 'random' },
                'MEMORY',
                { 'description' => 'MEMORY', 'name' => 'memory' },
                'FF',
                { 'description' => 'FF', 'name' => 'ff' },
                'REW',
                { 'description' => 'REW', 'name' => 'rew' },
                'STBY',
                { 'description' => 'STANDBY', 'name' => 'stby' }
            }
        },
        'CPT',
        {
            'description' => 'Universal PORT Operation Command',
            'name'        => 'universal-port',
            'values'      => {
                'SETUP',
                { 'description' => 'SETUP', 'name' => 'setup' },
                'UP',
                { 'description' => 'UP/Tuning Up', 'name' => 'up' },
                'DOWN',
                {
                    'description' => 'DOWN/Tuning Down',
                    'name'        => 'down'
                },
                'LEFT',
                {
                    'description' => 'LEFT/Multicast Down',
                    'name'        => 'left'
                },
                'RIGHT',
                {
                    'description' => 'RIGHT/Multicast Up',
                    'name'        => 'right'
                },
                'ENTER',
                { 'description' => 'ENTER', 'name' => 'enter' },
                'RETURN',
                { 'description' => 'RETURN', 'name' => 'return' },
                'DISP',
                { 'description' => 'DISPLAY', 'name' => 'disp' },
                'PLAY',
                { 'description' => 'PLAY/BAND', 'name' => 'play' },
                'STOP',
                { 'description' => 'STOP', 'name' => 'stop' },
                'PAUSE',
                { 'description' => 'PAUSE', 'name' => 'pause' },
                'SKIP.F',
                { 'description' => '>>I', 'name' => 'skip-f' },
                'SKIP.R',
                { 'description' => 'I<<', 'name' => 'skip-r' },
                'FF',
                { 'description' => 'FF >>', 'name' => 'ff' },
                'REW',
                { 'description' => 'REW <<', 'name' => 'rew' },
                'REPEAT',
                { 'description' => 'REPEAT', 'name' => 'repeat' },
                'SHUFFLE',
                { 'description' => 'SHUFFLE', 'name' => 'shuffle' },
                'PRSUP',
                { 'description' => 'PRESET UP', 'name' => 'prsup' },
                'PRSDN',
                {
                    'description' => 'PRESET DOWN',
                    'name'        => 'prsdn'
                },
                '0',
                { 'description' => '0.0', 'name' => '0' },
                '1',
                { 'description' => '1.0', 'name' => '1' },
                '2',
                { 'description' => '2.0', 'name' => '2' },
                '3',
                { 'description' => '3.0', 'name' => '3' },
                '4',
                { 'description' => '4.0', 'name' => '4' },
                '5',
                { 'description' => '5.0', 'name' => '5' },
                '6',
                { 'description' => '6.0', 'name' => '6' },
                '7',
                { 'description' => '7.0', 'name' => '7' },
                '8',
                { 'description' => '8.0', 'name' => '8' },
                '9',
                { 'description' => '9.0', 'name' => '9' },
                '10',
                {
                    'description' => '10/+10/Direct Tuning',
                    'name'        => '10'
                },
                'MODE',
                { 'description' => 'MODE', 'name' => 'mode' }
            }
        },
        'IAT',
        {
            'description' => 'iPod Artist Name Info {Universal Port Dock Only}',
            'name'        => 'ipod-artist-name-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' =>
'iPod Artist Name {variable-length, 64 letters max ASCII letter only}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Artist Name',
                    'name'        => 'query'
                }
            }
        },
        'IAL',
        {
            'description' => 'iPod Album Name Info {Universal Port Dock Only}',
            'name'        => 'ipod-album-name-info',
            'values'      => {
                'nnnnnnn',
                {
                    'description' =>
'iPod Album Name {variable-length, 64 letters max ASCII letter only}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Album Name',
                    'name'        => 'query'
                }
            }
        },
        'ITI',
        {
            'description' => 'iPod Title Name {Universal Port Dock Only}',
            'name'        => 'ipod-title-name',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' =>
'iPod Title Name {variable-length, 64 letters max ASCII letter only}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Title Name',
                    'name'        => 'query'
                }
            }
        },
        'ITM',
        {
            'description' => 'iPod Time Info {Universal Port Dock Only}',
            'name'        => 'ipod-time-info',
            'values'      => {
                'mm:ss/mm:ss',
                {
                    'description' =>
                      'iPod Time Info {Elapsed time/Track Time Max 99:59}',
                    'name' => 'mm-ss-mm-ss'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Time Info',
                    'name'        => 'query'
                }
            }
        },
        'ITR',
        {
            'description' => 'iPod Track Info {Universal Port Dock Only}',
            'name'        => 'ipod-track-info',
            'values'      => {
                'cccc/tttt',
                {
                    'description' =>
                      'iPod Track Info {Current Track/Toral Track Max 9999}',
                    'name' => 'cccc-tttt'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Time Info',
                    'name'        => 'query'
                }
            }
        },
        'IST',
        {
            'description' => 'iPod Play Status {Universal Port Dock Only}',
            'name'        => 'ipod-play-status',
            'values'      => {
                'prs',
                {
                    'description' =>
'iPod Play Status {3 letters}\np -> Play Status "S" STOP, "P" Play, "p" Pause, "F" FF, "R" FR\nr -> Repeat Status "-" no Repeat, "R" All Repeat, "1" Repeat 1,\ns -> Shuffle Status "-" no Shuffle, "S" Shuffle, "A" Album Shuffle',
                    'name' => 'prs'
                },
                'QSTN',
                {
                    'description' => 'gets the iPod Play Status',
                    'name'        => 'query'
                }
            }
        },
        'ILS',
        {
            'description' =>
              'iPod List Info {Universal Port Dock Extend Mode Only}',
            'name'   => 'ipod-list-info',
            'values' => {
                'tlpnnnnnnnnnn',
                {
                    'description' =>
'iPod List Info\nt ->Information Type {A : ASCII letter, C : Cursor Info}\nwhen t = A,\n  l ->Line Info {0-9 : 1st to 10th Line}\n  nnnnnnnnn:Listed data {variable-length, 64 letters max ASCII letter only}\n  p ->Property {- : no}\nwhen t = C,\n  l ->Cursor Position {0-9 : 1st to 10th Line, - : No Cursor}\n  p ->Update Type {P : Page Infomation Update { Page Clear or Disable List Info} , C : Cursor Position Update}',
                    'name' => 'None'
                }
            }
        },
        'IMD',
        {
            'description' => 'iPod Mode Change {Universal Port Dock Only}',
            'name'        => 'ipod-mode-change',
            'values'      => {
                'STD',
                {
                    'description' => 'Standerd Mode',
                    'name'        => 'std'
                },
                'EXT',
                {
                    'description' => 'Extend Mode{If available}',
                    'name'        => 'ext'
                },
                'VDC',
                {
                    'description' => 'Video Contents in Extended Mode',
                    'name'        => 'vdc'
                },
                'QSTN',
                {
                    'description' => 'gets iPod Mode Status',
                    'name'        => 'query'
                }
            }
        },
        'UTN',
        {
            'description' => 'Tuning Command {Universal Port Dock Only}',
            'name'        => 'tunerFrequency',
            'values'      => {
                'nnnnn',
                {
                    'description' =>
'sets Directly Tuning Frequency {FM nnn.nn MHz / AM nnnnn kHz}',
                    'name' => 'None'
                },
                'UP',
                {
                    'description' => 'sets Tuning Frequency Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Tuning Frequency Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Tuning Frequency',
                    'name'        => 'query'
                }
            }
        },
        'UPR',
        {
            'description' => 'DAB Preset Command {Universal Port Dock Only}',
            'name'        => 'dab-preset',
            'values'      => {
                '{1,40}',
                {
                    'description' =>
                      'sets Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'no-1-40'
                },
                'UP',
                {
                    'description' => 'sets Preset No. Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Preset No. Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Preset No.',
                    'name'        => 'query'
                }
            }
        },
        'UPM',
        {
            'description' => 'Preset Memory Command {Universal Port Dock Only}',
            'name'        => 'preset-memory',
            'values'      => {
                '{1,40}',
                {
                    'description' =>
'Memory Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'None'
                }
            }
        },
        'UHP',
        {
            'description' =>
              'HD Radio Channel Program Command {Universal Port Dock Only}',
            'name'   => 'hd-radio-channel-program',
            'values' => {
                '{1,8}',
                {
                    'description' => 'sets directly HD Radio Channel Program',
                    'name'        => 'directly'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Channel Program',
                    'name'        => 'query'
                }
            }
        },
        'UHB',
        {
            'description' =>
              'HD Radio Blend Mode Command {Universal Port Dock Only}',
            'name'   => 'hd-radio-blend-mode',
            'values' => {
                '00',
                {
                    'description' => 'sets HD Radio Blend Mode "Auto"',
                    'name'        => 'auto'
                },
                '01',
                {
                    'description' => 'sets HD Radio Blend Mode "Analog"',
                    'name'        => 'analog'
                },
                'QSTN',
                {
                    'description' => 'gets the HD Radio Blend Mode Status',
                    'name'        => 'query'
                }
            }
        },
        'UHA',
        {
            'description' =>
              'HD Radio Artist Name Info {Universal Port Dock Only}',
            'name'   => 'hd-radio-artist-name-info',
            'values' => {
                'nnnnnnnnnn',
                {
                    'description' =>
                      'HD Radio Artist Name {variable-length, 64 letters max}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Artist Name',
                    'name'        => 'query'
                }
            }
        },
        'UHC',
        {
            'description' =>
              'HD Radio Channel Name Info {Universal Port Dock Only}',
            'name'   => 'hd-radio-channel-name-info',
            'values' => {
                'nnnnnnn',
                {
                    'description' =>
                      'HD Radio Channel Name {Station Name} {7lettters}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Channel Name',
                    'name'        => 'query'
                }
            }
        },
        'UHT',
        {
            'description' => 'HD Radio Title Info {Universal Port Dock Only}',
            'name'        => 'hd-radio-title-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' =>
                      'HD Radio Title {variable-length, 64 letters max}',
                    'name' => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Title',
                    'name'        => 'query'
                }
            }
        },
        'UHD',
        {
            'description' => 'HD Radio Detail Info {Universal Port Dock Only}',
            'name'        => 'hd-radio-detail-info',
            'values'      => {
                'nnnnnnnnnn',
                {
                    'description' => 'HD Radio Title',
                    'name'        => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets HD Radio Title',
                    'name'        => 'query'
                }
            }
        },
        'UHS',
        {
            'description' => 'HD Radio Tuner Status {Universal Port Dock Only}',
            'name'        => 'hd-radio-tuner-status',
            'values'      => {
                'mmnnoo',
                {
                    'description' =>
'HD Radio Tuner Status {3 bytes}\nmm -> "00" not HD, "01" HD\nnn -> current Program "01"-"08"\noo -> receivable Program {8 bits are represented in hexadecimal notation. Each bit shows receivable or not.}',
                    'name' => 'mmnnoo'
                },
                'QSTN',
                {
                    'description' => 'gets the HD Radio Tuner Status',
                    'name'        => 'query'
                }
            }
        },
        'UDS',
        {
            'description' => 'DAB Station Name {Universal Port Dock Only}',
            'name'        => 'dab-station-name',
            'values'      => {
                'nnnnnnnnn',
                {
                    'description' => 'Sation Name {9 letters}',
                    'name'        => 'None'
                },
                'QSTN',
                {
                    'description' => 'gets The Tuning Frequency',
                    'name'        => 'query'
                }
            }
        },
        'UDD',
        {
            'description' => 'DAB Display Info {Universal Port Dock Only}',
            'name'        => 'dab-display-info',
            'values'      => {
                'PT:nnnnnnnn',
                {
                    'description' => 'DAB Program Type {8 letters}',
                    'name'        => 'None'
                },
                'AT:mmmkbps/nnnnnn',
                {
                    'description' =>
'DAB Bitrate & Audio Type {m:Bitrate xxxkbps,n:Audio Type Stereo/Mono}',
                    'name' => 'None'
                },
                'MN:nnnnnnnnn',
                {
                    'description' => 'DAB Multiplex Name {9 letters}',
                    'name'        => 'None'
                },
                'MF:mmm/nnnn.nnMHz',
                {
                    'description' =>
                      'DAB Multiplex Band ID{mmm} & Freq{nnnn.nnMHz} Info',
                    'name' => 'None'
                },
                'PT',
                {
                    'description' => 'gets & display DAB Program Info',
                    'name'        => 'pt'
                },
                'AT',
                {
                    'description' => 'gets & display DAB Bitrate & Audio Type',
                    'name'        => 'at'
                },
                'MN',
                {
                    'description' => 'gets & display DAB Multicast Name',
                    'name'        => 'mn'
                },
                'MF',
                {
                    'description' =>
                      'gets & display DAB Multicast Band & Freq Info',
                    'name' => 'mf'
                },
                'UP',
                {
                    'description' =>
                      'gets & dispaly DAB Infomation Wrap-Around Up',
                    'name' => 'up'
                }
            }
        },
        'NRI',
        {
            'description' => 'Get device info in XML format',
            'name'        => 'net-receiver-information',
        }
    },
    '2' => {
        'ZPW',
        {
            'description' => 'Zone2 Power Command',
            'name'        => 'power',
            'values'      => {
                '00',
                {
                    'description' => 'sets Zone2 Standby',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Zone2 On',
                    'name'        => 'on'
                },
                'QSTN',
                {
                    'description' => 'gets the Zone2 Power Status',
                    'name'        => 'query'
                }
            }
        },
        'ZMT',
        {
            'description' => 'Zone2 Muting Command',
            'name'        => 'mute',
            'values'      => {
                '00',
                {
                    'description' => 'sets Zone2 Muting Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Zone2 Muting On',
                    'name'        => 'on'
                },
                'TG',
                {
                    'description' => 'sets Zone2 Muting Wrap-Around',
                    'name'        => 'toggle'
                },
                'QSTN',
                {
                    'description' => 'gets the Zone2 Muting Status',
                    'name'        => 'query'
                }
            }
        },
        'ZVL',
        {
            'description' => 'Zone2 Volume Command',
            'name'        => 'volume',
            'values'      => {
                '{0,100}',
                {
                    'description' =>
                      'Volume Level 0 100 { In hexadecimal representation}',
                    'name' => 'None'
                },
                '{0,80}',
                {
                    'description' =>
                      'Volume Level 0 80 { In hexadecimal representation}',
                    'name' => 'None'
                },
                'UP',
                {
                    'description' => 'sets Volume Level Up',
                    'name'        => 'level-up'
                },
                'DOWN',
                {
                    'description' => 'sets Volume Level Down',
                    'name'        => 'level-down'
                },
                'QSTN',
                {
                    'description' => 'gets the Volume Level',
                    'name'        => 'query'
                }
            }
        },
        'ZTN',
        {
            'description' => 'Zone2 Tone Command',
            'name'        => 'tone',
            'values'      => {
                'B{xx}',
                {
                    'description' =>
'sets Zone2 Bass {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 'bass-xx-is-a-00-a-10-0-10-2-step'
                },
                'T{xx}',
                {
                    'description' =>
'sets Zone2 Treble {xx is "-A"..."00"..."+A"[-10...0...+10 2 step]',
                    'name' => 'treble-xx-is-a-00-a-10-0-10-2-step'
                },
                'BUP',
                {
                    'description' => 'sets Bass Up {2 Step}',
                    'name'        => 'bass-up'
                },
                'BDOWN',
                {
                    'description' => 'sets Bass Down {2 Step}',
                    'name'        => 'bass-down'
                },
                'TUP',
                {
                    'description' => 'sets Treble Up {2 Step}',
                    'name'        => 'treble-up'
                },
                'TDOWN',
                {
                    'description' => 'sets Treble Down {2 Step}',
                    'name'        => 'treble-down'
                },
                'QSTN',
                {
                    'description' => 'gets Zone2 Tone {"BxxTxx"}',
                    'name'        => 'query'
                }
            }
        },
        'ZBL',
        {
            'description' => 'Zone2 Balance Command',
            'name'        => 'balance',
            'values'      => {
                '{xx}',
                {
                    'description' =>
'sets Zone2 Balance {xx is "-A"..."00"..."+A"[L+10...0...R+10 2 step]',
                    'name' => 'xx-is-a-00-a-l-10-0-r-10-2-step'
                },
                'UP',
                {
                    'description' => 'sets Balance Up {to R 2 Step}',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Balance Down {to L 2 Step}',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets Zone2 Balance',
                    'name'        => 'query'
                }
            }
        },
        'SLZ',
        {
            'description' => 'ZONE2 Selector Command',
            'name'        => 'input',
            'values'      => {
                '00',
                {
                    'description' => 'sets VIDEO1, VCR/DVR',
                    'name'        => [ 'video1', 'vcr', 'dvr' ]
                },
                '01',
                {
                    'description' => 'sets VIDEO2, CBL/SAT',
                    'name'        => [ 'video2', 'cbl', 'sat' ]
                },
                '02',
                {
                    'description' => 'sets VIDEO3, GAME/TV, GAME',
                    'name'        => [ 'video3', 'game' ]
                },
                '03',
                {
                    'description' => 'sets VIDEO4, AUX1{AUX}',
                    'name'        => [ 'video4', 'aux1' ]
                },
                '04',
                {
                    'description' => 'sets VIDEO5, AUX2',
                    'name'        => [ 'video5', 'aux2' ]
                },
                '05',
                {
                    'description' => 'sets VIDEO6, PC',
                    'name'        => [ 'video6', 'pc' ]
                },
                '06',
                {
                    'description' => 'sets VIDEO7',
                    'name'        => 'video7'
                },
                '07',
                {
                    'description' => 'sets Hidden1',
                    'name'        => 'hidden1'
                },
                '08',
                {
                    'description' => 'sets Hidden2',
                    'name'        => 'hidden2'
                },
                '09',
                {
                    'description' => 'sets Hidden3',
                    'name'        => 'hidden3'
                },
                '10',
                {
                    'description' => 'sets DVD, BD/DVD',
                    'name'        => [ 'dvd', 'bd', 'dvd' ]
                },
                '20',
                {
                    'description' => 'sets TAPE{1}',
                    'name'        => 'tape'
                },
                '21',
                {
                    'description' => 'sets TAPE2',
                    'name'        => 'tape2'
                },
                '22',
                {
                    'description' => 'sets PHONO',
                    'name'        => 'phono'
                },
                '23',
                {
                    'description' => 'sets CD, TV/CD',
                    'name'        => [ 'tv-cd', 'tv', 'cd' ]
                },
                '24',
                { 'description' => 'sets FM', 'name' => 'fm' },
                '25',
                { 'description' => 'sets AM', 'name' => 'am' },
                '26',
                {
                    'description' => 'sets TUNER',
                    'name'        => 'tuner'
                },
                '27',
                {
                    'description' => 'sets MUSIC SERVER, P4S, DLNA',
                    'name'        => [ 'music-server', 'p4s', 'dlna' ]
                },
                '28',
                {
                    'description' => 'sets INTERNET RADIO, iRadio Favorite',
                    'name'        => [ 'internet-radio', 'iradio-favorite' ]
                },
                '29',
                {
                    'description' => 'sets USB/USB{Front}',
                    'name'        => ['usb']
                },
                '2A',
                {
                    'description' => 'sets USB{Rear}',
                    'name'        => 'usb-rear'
                },
                '2B',
                {
                    'description' => 'sets NETWORK, NET',
                    'name'        => [ 'network', 'net' ]
                },
                '2C',
                {
                    'description' => 'sets USB{toggle}',
                    'name'        => 'usb-toggle'
                },
                '40',
                {
                    'description' => 'sets Universal PORT',
                    'name'        => 'universal-port'
                },
                '30',
                {
                    'description' => 'sets MULTI CH',
                    'name'        => 'multi-ch'
                },
                '31',
                { 'description' => 'sets XM', 'name' => 'xm' },
                '32',
                {
                    'description' => 'sets SIRIUS',
                    'name'        => 'sirius'
                },
                '7F',
                { 'description' => 'sets OFF', 'name' => 'off' },
                '80',
                {
                    'description' => 'sets SOURCE',
                    'name'        => 'source'
                },
                'UP',
                {
                    'description' => 'sets Selector Position Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Selector Position Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Selector Position',
                    'name'        => 'query'
                }
            }
        },
        'TUZ',
        {
            'description' => 'Tuning Command',
            'name'        => 'tunerFrequency',
            'values'      => {
                'nnnnn',
                {
                    'description' =>
'sets Directly Tuning Frequency {FM nnn.nn MHz / AM nnnnn kHz / SR nnnnn ch}',
                    'name' => 'None'
                },
                'DIRECT',
                {
                    'description' => 'starts/restarts Direct Tuning Mode',
                    'name'        => 'direct'
                },
                '0',
                {
                    'description' => 'sets 0 in Direct Tuning Mode',
                    'name'        => '0-in-direct-mode'
                },
                '1',
                {
                    'description' => 'sets 1 in Direct Tuning Mode',
                    'name'        => '1-in-direct-mode'
                },
                '2',
                {
                    'description' => 'sets 2 in Direct Tuning Mode',
                    'name'        => '2-in-direct-mode'
                },
                '3',
                {
                    'description' => 'sets 3 in Direct Tuning Mode',
                    'name'        => '3-in-direct-mode'
                },
                '4',
                {
                    'description' => 'sets 4 in Direct Tuning Mode',
                    'name'        => '4-in-direct-mode'
                },
                '5',
                {
                    'description' => 'sets 5 in Direct Tuning Mode',
                    'name'        => '5-in-direct-mode'
                },
                '6',
                {
                    'description' => 'sets 6 in Direct Tuning Mode',
                    'name'        => '6-in-direct-mode'
                },
                '7',
                {
                    'description' => 'sets 7 in Direct Tuning Mode',
                    'name'        => '7-in-direct-mode'
                },
                '8',
                {
                    'description' => 'sets 8 in Direct Tuning Mode',
                    'name'        => '8-in-direct-mode'
                },
                '9',
                {
                    'description' => 'sets 9 in Direct Tuning Mode',
                    'name'        => '9-in-direct-mode'
                },
                'UP',
                {
                    'description' => 'sets Tuning Frequency Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Tuning Frequency Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Tuning Frequency',
                    'name'        => 'query'
                }
            }
        },
        'PRZ',
        {
            'description' => 'Preset Command',
            'name'        => 'preset',
            'values'      => {
                '{1,40}',
                {
                    'description' =>
                      'sets Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'no-1-40'
                },
                '{1,30}',
                {
                    'description' =>
                      'sets Preset No. 1 - 30 { In hexadecimal representation}',
                    'name' => 'no-1-30'
                },
                'UP',
                {
                    'description' => 'sets Preset No. Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Preset No. Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Preset No.',
                    'name'        => 'query'
                }
            }
        },
        'NTC',
        {
            'description' =>
              'Net-Tune/Network Operation Command{Net-Tune Model Only}',
            'name'   => 'net-usb',
            'values' => {
                'PLAYz',
                {
                    'description' => 'PLAY KEY',
                    'name'        => 'playz'
                },
                'STOPz',
                { 'description' => 'STOP KEY', 'name' => 'stopz' },
                'PAUSEz',
                {
                    'description' => 'PAUSE KEY',
                    'name'        => 'pausez'
                },
                'TRUPz',
                {
                    'description' => 'TRACK UP KEY',
                    'name'        => 'trupz'
                },
                'TRDNz',
                {
                    'description' => 'TRACK DOWN KEY',
                    'name'        => 'trdnz'
                }
            }
        },
        'NTZ',
        {
            'description' =>
              'Net-Tune/Network Operation Command{Network Model Only}',
            'name'   => 'net-usb',
            'values' => {
                'PLAY',
                {
                    'description' => 'PLAY KEY',
                    'name'        => 'play'
                },
                'STOP',
                { 'description' => 'STOP KEY', 'name' => 'stop' },
                'PAUSE',
                { 'description' => 'PAUSE KEY', 'name' => 'pause' },
                'TRUP',
                {
                    'description' => 'TRACK UP KEY',
                    'name'        => 'trup'
                },
                'TRDN',
                {
                    'description' => 'TRACK DOWN KEY',
                    'name'        => 'trdn'
                },
                'CHUP',
                {
                    'description' => 'CH UP{for iRadio}',
                    'name'        => 'chup'
                },
                'CHDN',
                {
                    'description' => 'CH DOWN{for iRadio}',
                    'name'        => 'chdn'
                },
                'FF',
                {
                    'description' => 'FF KEY {CONTINUOUS*} {for iPod 1wire}',
                    'name'        => 'ff'
                },
                'REW',
                {
                    'description' => 'REW KEY {CONTINUOUS*} {for iPod 1wire}',
                    'name'        => 'rew'
                },
                'REPEAT',
                {
                    'description' => 'REPEAT KEY{for iPod 1wire}',
                    'name'        => 'repeat'
                },
                'RANDOM',
                {
                    'description' => 'RANDOM KEY{for iPod 1wire}',
                    'name'        => 'random'
                },
                'DISPLAY',
                {
                    'description' => 'DISPLAY KEY{for iPod 1wire}',
                    'name'        => 'display'
                },
                'RIGHT',
                {
                    'description' => 'RIGHT KEY{for iPod 1wire}',
                    'name'        => 'right'
                },
                'LEFT',
                {
                    'description' => 'LEFT KEY{for iPod 1wire}',
                    'name'        => 'left'
                },
                'UP',
                {
                    'description' => 'UP KEY{for iPod 1wire}',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'DOWN KEY{for iPod 1wire}',
                    'name'        => 'down'
                },
                'SELECT',
                {
                    'description' => 'SELECT KEY{for iPod 1wire}',
                    'name'        => 'select'
                },
                'RETURN',
                {
                    'description' => 'RETURN KEY{for iPod 1wire}',
                    'name'        => 'return'
                }
            }
        },
        'NPZ',
        {
            'description' =>
              'Internet Radio Preset Command {Network Model Only}',
            'name'   => 'internet-radio-preset',
            'values' => {
                '{1,40}',
                {
                    'description' =>
                      'sets Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'no-1-40'
                }
            }
        },
        'LMZ',
        {
            'description' => 'Listening Mode Command',
            'name'        => 'listening-mode',
            'values'      => {
                '00',
                {
                    'description' => 'sets STEREO',
                    'name'        => 'stereo'
                },
                '01',
                {
                    'description' => 'sets DIRECT',
                    'name'        => 'direct'
                },
                '0F',
                { 'description' => 'sets MONO', 'name' => 'mono' },
                '12',
                {
                    'description' => 'sets MULTIPLEX',
                    'name'        => 'multiplex'
                },
                '87',
                {
                    'description' => 'sets DVS{Pl2}',
                    'name'        => 'dvs'
                },
                '88',
                {
                    'description' => 'sets DVS{NEO6}',
                    'name'        => 'dvs'
                }
            }
        },
        'LTZ',
        {
            'description' => 'Late Night Command',
            'name'        => 'late-night',
            'values'      => {
                '00',
                {
                    'description' => 'sets Late Night Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Late Night Low',
                    'name'        => 'low'
                },
                '02',
                {
                    'description' => 'sets Late Night High',
                    'name'        => 'high'
                },
                'UP',
                {
                    'description' => 'sets Late Night State Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Late Night Level',
                    'name'        => 'query'
                }
            }
        },
        'RAZ',
        {
            'description' => 'Re-EQ/Academy Filter Command',
            'name'        => 're-eq-academy-filter',
            'values'      => {
                '00',
                {
                    'description' => 'sets Both Off',
                    'name'        => 'both-off'
                },
                '01',
                {
                    'description' => 'sets Re-EQ On',
                    'name'        => 'on'
                },
                '02',
                {
                    'description' => 'sets Academy On',
                    'name'        => 'on'
                },
                'UP',
                {
                    'description' => 'sets Re-EQ/Academy State Wrap-Around Up',
                    'name'        => 'up'
                },
                'QSTN',
                {
                    'description' => 'gets The Re-EQ/Academy State',
                    'name'        => 'query'
                }
            }
        }
    },
    '3' => {
        'PW3',
        {
            'description' => 'Zone3 Power Command',
            'name'        => 'power',
            'values'      => {
                '00',
                {
                    'description' => 'sets Zone3 Standby',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Zone3 On',
                    'name'        => 'on'
                },
                'QSTN',
                {
                    'description' => 'gets the Zone3 Power Status',
                    'name'        => 'query'
                }
            }
        },
        'MT3',
        {
            'description' => 'Zone3 Muting Command',
            'name'        => 'mute',
            'values'      => {
                '00',
                {
                    'description' => 'sets Zone3 Muting Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Zone3 Muting On',
                    'name'        => 'on'
                },
                'TG',
                {
                    'description' => 'sets Zone3 Muting Wrap-Around',
                    'name'        => 'toggle'
                },
                'QSTN',
                {
                    'description' => 'gets the Zone3 Muting Status',
                    'name'        => 'query'
                }
            }
        },
        'VL3',
        {
            'description' => 'Zone3 Volume Command',
            'name'        => 'volume',
            'values'      => {
                '{0,100}',
                {
                    'description' =>
                      'Volume Level 0 100 { In hexadecimal representation}',
                    'name' => 'None'
                },
                '{0,80}',
                {
                    'description' =>
                      'Volume Level 0 80 { In hexadecimal representation}',
                    'name' => 'None'
                },
                'UP',
                {
                    'description' => 'sets Volume Level Up',
                    'name'        => 'level-up'
                },
                'DOWN',
                {
                    'description' => 'sets Volume Level Down',
                    'name'        => 'level-down'
                },
                'QSTN',
                {
                    'description' => 'gets the Volume Level',
                    'name'        => 'query'
                }
            }
        },
        'TN3',
        {
            'description' => 'Zone3 Tone Command',
            'name'        => 'tone',
            'values'      => {
                'B{xx}',
                {
                    'description' =>
'Zone3 Bass {xx is "-A"..."00"..."+A"[-10...0...+10 2 step}',
                    'name' => 'b-xx'
                },
                'T{xx}',
                {
                    'description' =>
'Zone3 Treble {xx is "-A"..."00"..."+A"[-10...0...+10 2 step}',
                    'name' => 't-xx'
                },
                'BUP',
                {
                    'description' => 'sets Bass Up {2 Step}',
                    'name'        => 'bass-up'
                },
                'BDOWN',
                {
                    'description' => 'sets Bass Down {2 Step}',
                    'name'        => 'bass-down'
                },
                'TUP',
                {
                    'description' => 'sets Treble Up {2 Step}',
                    'name'        => 'treble-up'
                },
                'TDOWN',
                {
                    'description' => 'sets Treble Down {2 Step}',
                    'name'        => 'treble-down'
                },
                'QSTN',
                {
                    'description' => 'gets Zone3 Tone {"BxxTxx"}',
                    'name'        => 'query'
                }
            }
        },
        'BL3',
        {
            'description' => 'Zone3 Balance Command',
            'name'        => 'balance',
            'values'      => {
                '{xx}',
                {
                    'description' =>
'Zone3 Balance {xx is "-A"..."00"..."+A"[L+10...0...R+10 2 step}',
                    'name' => 'xx'
                },
                'UP',
                {
                    'description' => 'sets Balance Up {to R 2 Step}',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Balance Down {to L 2 Step}',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets Zone3 Balance',
                    'name'        => 'query'
                }
            }
        },
        'SL3',
        {
            'description' => 'ZONE3 Selector Command',
            'name'        => 'input',
            'values'      => {
                '00',
                {
                    'description' => 'sets VIDEO1, VCR/DVR',
                    'name'        => [ 'video1', 'vcr', 'dvr' ]
                },
                '01',
                {
                    'description' => 'sets VIDEO2, CBL/SAT',
                    'name'        => [ 'video2', 'cbl', 'sat' ]
                },
                '02',
                {
                    'description' => 'sets VIDEO3, GAME/TV, GAME',
                    'name'        => [ 'video3', 'game' ]
                },
                '03',
                {
                    'description' => 'sets VIDEO4, AUX1{AUX}',
                    'name'        => [ 'video4', 'aux1' ]
                },
                '04',
                {
                    'description' => 'sets VIDEO5, AUX2',
                    'name'        => [ 'video5', 'aux2' ]
                },
                '05',
                {
                    'description' => 'sets VIDEO6, PC',
                    'name'        => [ 'video6', 'pc' ]
                },
                '06',
                {
                    'description' => 'sets VIDEO7',
                    'name'        => 'video7'
                },
                '07',
                {
                    'description' => 'sets Hidden1',
                    'name'        => 'hidden1'
                },
                '08',
                {
                    'description' => 'sets Hidden2',
                    'name'        => 'hidden2'
                },
                '09',
                {
                    'description' => 'sets Hidden3',
                    'name'        => 'hidden3'
                },
                '10',
                { 'description' => 'sets DVD', 'name' => 'dvd' },
                '20',
                {
                    'description' => 'sets TAPE{1}',
                    'name'        => 'tape'
                },
                '21',
                {
                    'description' => 'sets TAPE2',
                    'name'        => 'tape2'
                },
                '22',
                {
                    'description' => 'sets PHONO',
                    'name'        => 'phono'
                },
                '23',
                {
                    'description' => 'sets CD, TV/CD',
                    'name'        => [ 'tv-cd', 'tv', 'cd' ]
                },
                '24',
                { 'description' => 'sets FM', 'name' => 'fm' },
                '25',
                { 'description' => 'sets AM', 'name' => 'am' },
                '26',
                {
                    'description' => 'sets TUNER',
                    'name'        => 'tuner'
                },
                '27',
                {
                    'description' => 'sets MUSIC SERVER, P4S, DLNA',
                    'name'        => [ 'music-server', 'p4s', 'dlna' ]
                },
                '28',
                {
                    'description' => 'sets INTERNET RADIO, iRadio Favorite',
                    'name'        => [ 'internet-radio', 'iradio-favorite' ]
                },
                '29',
                {
                    'description' => 'sets USB/USB{Front}',
                    'name'        => ['usb']
                },
                '2A',
                {
                    'description' => 'sets USB{Rear}',
                    'name'        => 'usb-rear'
                },
                '2B',
                {
                    'description' => 'sets NETWORK, NET',
                    'name'        => [ 'network', 'net' ]
                },
                '2C',
                {
                    'description' => 'sets USB{toggle}',
                    'name'        => 'usb-toggle'
                },
                '40',
                {
                    'description' => 'sets Universal PORT',
                    'name'        => 'universal-port'
                },
                '30',
                {
                    'description' => 'sets MULTI CH',
                    'name'        => 'multi-ch'
                },
                '31',
                { 'description' => 'sets XM', 'name' => 'xm' },
                '32',
                {
                    'description' => 'sets SIRIUS',
                    'name'        => 'sirius'
                },
                '80',
                {
                    'description' => 'sets SOURCE',
                    'name'        => 'source'
                },
                'UP',
                {
                    'description' => 'sets Selector Position Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Selector Position Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Selector Position',
                    'name'        => 'query'
                }
            }
        },
        'TU3',
        {
            'description' => 'Tuning Command',
            'name'        => 'tunerFrequency',
            'values'      => {
                'nnnnn',
                {
                    'description' =>
'sets Directly Tuning Frequency {FM nnn.nn MHz / AM nnnnn kHz / SR nnnnn ch}',
                    'name' => 'None'
                },
                'DIRECT',
                {
                    'description' => 'starts/restarts Direct Tuning Mode',
                    'name'        => 'direct'
                },
                '0',
                {
                    'description' => 'sets 0 in Direct Tuning Mode',
                    'name'        => '0-in-direct-mode'
                },
                '1',
                {
                    'description' => 'sets 1 in Direct Tuning Mode',
                    'name'        => '1-in-direct-mode'
                },
                '2',
                {
                    'description' => 'sets 2 in Direct Tuning Mode',
                    'name'        => '2-in-direct-mode'
                },
                '3',
                {
                    'description' => 'sets 3 in Direct Tuning Mode',
                    'name'        => '3-in-direct-mode'
                },
                '4',
                {
                    'description' => 'sets 4 in Direct Tuning Mode',
                    'name'        => '4-in-direct-mode'
                },
                '5',
                {
                    'description' => 'sets 5 in Direct Tuning Mode',
                    'name'        => '5-in-direct-mode'
                },
                '6',
                {
                    'description' => 'sets 6 in Direct Tuning Mode',
                    'name'        => '6-in-direct-mode'
                },
                '7',
                {
                    'description' => 'sets 7 in Direct Tuning Mode',
                    'name'        => '7-in-direct-mode'
                },
                '8',
                {
                    'description' => 'sets 8 in Direct Tuning Mode',
                    'name'        => '8-in-direct-mode'
                },
                '9',
                {
                    'description' => 'sets 9 in Direct Tuning Mode',
                    'name'        => '9-in-direct-mode'
                },
                'UP',
                {
                    'description' => 'sets Tuning Frequency Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Tuning Frequency Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Tuning Frequency',
                    'name'        => 'query'
                }
            }
        },
        'PR3',
        {
            'description' => 'Preset Command',
            'name'        => 'preset',
            'values'      => {
                '{1,40}',
                {
                    'description' =>
                      'sets Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'no-1-40'
                },
                '{1,30}',
                {
                    'description' =>
                      'sets Preset No. 1 - 30 { In hexadecimal representation}',
                    'name' => 'no-1-30'
                },
                'UP',
                {
                    'description' => 'sets Preset No. Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Preset No. Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Preset No.',
                    'name'        => 'query'
                }
            }
        },
        'NTC',
        {
            'description' =>
              'Net-Tune/Network Operation Command{Net-Tune Model Only}',
            'name'   => 'net-usb',
            'values' => {
                'PLAYz',
                {
                    'description' => 'PLAY KEY',
                    'name'        => 'playz'
                },
                'STOPz',
                { 'description' => 'STOP KEY', 'name' => 'stopz' },
                'PAUSEz',
                {
                    'description' => 'PAUSE KEY',
                    'name'        => 'pausez'
                },
                'TRUPz',
                {
                    'description' => 'TRACK UP KEY',
                    'name'        => 'trupz'
                },
                'TRDNz',
                {
                    'description' => 'TRACK DOWN KEY',
                    'name'        => 'trdnz'
                }
            }
        },
        'NT3',
        {
            'description' =>
              'Net-Tune/Network Operation Command{Network Model Only}',
            'name'   => 'net-usb',
            'values' => {
                'PLAY',
                {
                    'description' => 'PLAY KEY',
                    'name'        => 'play'
                },
                'STOP',
                { 'description' => 'STOP KEY', 'name' => 'stop' },
                'PAUSE',
                { 'description' => 'PAUSE KEY', 'name' => 'pause' },
                'TRUP',
                {
                    'description' => 'TRACK UP KEY',
                    'name'        => 'trup'
                },
                'TRDN',
                {
                    'description' => 'TRACK DOWN KEY',
                    'name'        => 'trdn'
                },
                'CHUP',
                {
                    'description' => 'CH UP{for iRadio}',
                    'name'        => 'chup'
                },
                'CHDN',
                {
                    'description' => 'CH DOWNP{for iRadio}',
                    'name'        => 'chdn'
                },
                'FF',
                {
                    'description' => 'FF KEY {CONTINUOUS*} {for iPod 1wire}',
                    'name'        => 'ff'
                },
                'REW',
                {
                    'description' => 'REW KEY {CONTINUOUS*} {for iPod 1wire}',
                    'name'        => 'rew'
                },
                'REPEAT',
                {
                    'description' => 'REPEAT KEY{for iPod 1wire}',
                    'name'        => 'repeat'
                },
                'RANDOM',
                {
                    'description' => 'RANDOM KEY{for iPod 1wire}',
                    'name'        => 'random'
                },
                'DISPLAY',
                {
                    'description' => 'DISPLAY KEY{for iPod 1wire}',
                    'name'        => 'display'
                },
                'RIGHT',
                {
                    'description' => 'RIGHT KEY{for iPod 1wire}',
                    'name'        => 'right'
                },
                'LEFT',
                {
                    'description' => 'LEFT KEY{for iPod 1wire}',
                    'name'        => 'left'
                },
                'UP',
                {
                    'description' => 'UP KEY{for iPod 1wire}',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'DOWN KEY{for iPod 1wire}',
                    'name'        => 'down'
                },
                'SELECT',
                {
                    'description' => 'SELECT KEY{for iPod 1wire}',
                    'name'        => 'select'
                },
                'RETURN',
                {
                    'description' => 'RETURN KEY{for iPod 1wire}',
                    'name'        => 'return'
                }
            }
        },
        'NP3',
        {
            'description' =>
              'Internet Radio Preset Command {Network Model Only}',
            'name'   => 'internet-radio-preset',
            'values' => {
                '{1,40}',
                {
                    'description' =>
                      'sets Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'no-1-40'
                }
            }
        }
    },
    '4' => {
        'PW4',
        {
            'description' => 'Zone4 Power Command',
            'name'        => 'power',
            'values'      => {
                '00',
                {
                    'description' => 'sets Zone4 Standby',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Zone4 On',
                    'name'        => 'on'
                },
                'QSTN',
                {
                    'description' => 'gets the Zone4 Power Status',
                    'name'        => 'query'
                }
            }
        },
        'MT4',
        {
            'description' => 'Zone4 Muting Command',
            'name'        => 'mute',
            'values'      => {
                '00',
                {
                    'description' => 'sets Zone4 Muting Off',
                    'name'        => 'off'
                },
                '01',
                {
                    'description' => 'sets Zone4 Muting On',
                    'name'        => 'on'
                },
                'TG',
                {
                    'description' => 'sets Zone4 Muting Wrap-Around',
                    'name'        => 'toggle'
                },
                'QSTN',
                {
                    'description' => 'gets the Zone4 Muting Status',
                    'name'        => 'query'
                }
            }
        },
        'VL4',
        {
            'description' => 'Zone4 Volume Command',
            'name'        => 'volume',
            'values'      => {
                '{0,100}',
                {
                    'description' =>
                      'Volume Level 0 100 { In hexadecimal representation}',
                    'name' => 'None'
                },
                '{0,80}',
                {
                    'description' =>
                      'Volume Level 0 80 { In hexadecimal representation}',
                    'name' => 'None'
                },
                'UP',
                {
                    'description' => 'sets Volume Level Up',
                    'name'        => 'level-up'
                },
                'DOWN',
                {
                    'description' => 'sets Volume Level Down',
                    'name'        => 'level-down'
                },
                'QSTN',
                {
                    'description' => 'gets the Volume Level',
                    'name'        => 'query'
                }
            }
        },
        'SL4',
        {
            'description' => 'ZONE4 Selector Command',
            'name'        => 'input',
            'values'      => {
                '00',
                {
                    'description' => 'sets VIDEO1, VCR/DVR',
                    'name'        => [ 'video1', 'vcr', 'dvr' ]
                },
                '01',
                {
                    'description' => 'sets VIDEO2, CBL/SAT',
                    'name'        => [ 'video2', 'cbl', 'sat' ]
                },
                '02',
                {
                    'description' => 'sets VIDEO3, GAME/TV, GAME',
                    'name'        => [ 'video3', 'game' ]
                },
                '03',
                {
                    'description' => 'sets VIDEO4, AUX1{AUX}',
                    'name'        => [ 'video4', 'aux1' ]
                },
                '04',
                {
                    'description' => 'sets VIDEO5, AUX2',
                    'name'        => [ 'video5', 'aux2' ]
                },
                '05',
                {
                    'description' => 'sets VIDEO6',
                    'name'        => 'video6'
                },
                '06',
                {
                    'description' => 'sets VIDEO7',
                    'name'        => 'video7'
                },
                '07',
                {
                    'description' => 'sets Hidden1',
                    'name'        => 'hidden1'
                },
                '08',
                {
                    'description' => 'sets Hidden2',
                    'name'        => 'hidden2'
                },
                '09',
                {
                    'description' => 'sets Hidden3',
                    'name'        => 'hidden3'
                },
                '10',
                { 'description' => 'sets DVD', 'name' => 'dvd' },
                '20',
                {
                    'description' => 'sets TAPE{1}, TV/TAPE',
                    'name'        => [ 'tape-1', 'tv', 'tape' ]
                },
                '21',
                {
                    'description' => 'sets TAPE2',
                    'name'        => 'tape2'
                },
                '22',
                {
                    'description' => 'sets PHONO',
                    'name'        => 'phono'
                },
                '23',
                {
                    'description' => 'sets CD, TV/CD',
                    'name'        => [ 'tv-cd', 'tv', 'cd' ]
                },
                '24',
                { 'description' => 'sets FM', 'name' => 'fm' },
                '25',
                { 'description' => 'sets AM', 'name' => 'am' },
                '26',
                {
                    'description' => 'sets TUNER',
                    'name'        => 'tuner'
                },
                '27',
                {
                    'description' => 'sets MUSIC SERVER, P4S, DLNA',
                    'name'        => [ 'music-server', 'p4s', 'dlna' ]
                },
                '28',
                {
                    'description' => 'sets INTERNET RADIO, iRadio Favorite',
                    'name'        => [ 'internet-radio', 'iradio-favorite' ]
                },
                '29',
                {
                    'description' => 'sets USB/USB{Front}',
                    'name'        => ['usb']
                },
                '2A',
                {
                    'description' => 'sets USB{Rear}',
                    'name'        => 'usb-rear'
                },
                '2B',
                {
                    'description' => 'sets NETWORK, NET',
                    'name'        => [ 'network', 'net' ]
                },
                '2C',
                {
                    'description' => 'sets USB{toggle}',
                    'name'        => 'usb-toggle'
                },
                '40',
                {
                    'description' => 'sets Universal PORT',
                    'name'        => 'universal-port'
                },
                '30',
                {
                    'description' => 'sets MULTI CH',
                    'name'        => 'multi-ch'
                },
                '31',
                { 'description' => 'sets XM', 'name' => 'xm' },
                '32',
                {
                    'description' => 'sets SIRIUS',
                    'name'        => 'sirius'
                },
                '80',
                {
                    'description' => 'sets SOURCE',
                    'name'        => 'source'
                },
                'UP',
                {
                    'description' => 'sets Selector Position Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Selector Position Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Selector Position',
                    'name'        => 'query'
                }
            }
        },
        'TU4',
        {
            'description' => 'Tuning Command',
            'name'        => 'tunerFrequency',
            'values'      => {
                'nnnnn',
                {
                    'description' =>
'sets Directly Tuning Frequency {FM nnn.nn MHz / AM nnnnn kHz}',
                    'name' => 'None'
                },
                'DIRECT',
                {
                    'description' => 'starts/restarts Direct Tuning Mode',
                    'name'        => 'direct'
                },
                '0',
                {
                    'description' => 'sets 0 in Direct Tuning Mode',
                    'name'        => '0-in-direct-mode'
                },
                '1',
                {
                    'description' => 'sets 1 in Direct Tuning Mode',
                    'name'        => '1-in-direct-mode'
                },
                '2',
                {
                    'description' => 'sets 2 in Direct Tuning Mode',
                    'name'        => '2-in-direct-mode'
                },
                '3',
                {
                    'description' => 'sets 3 in Direct Tuning Mode',
                    'name'        => '3-in-direct-mode'
                },
                '4',
                {
                    'description' => 'sets 4 in Direct Tuning Mode',
                    'name'        => '4-in-direct-mode'
                },
                '5',
                {
                    'description' => 'sets 5 in Direct Tuning Mode',
                    'name'        => '5-in-direct-mode'
                },
                '6',
                {
                    'description' => 'sets 6 in Direct Tuning Mode',
                    'name'        => '6-in-direct-mode'
                },
                '7',
                {
                    'description' => 'sets 7 in Direct Tuning Mode',
                    'name'        => '7-in-direct-mode'
                },
                '8',
                {
                    'description' => 'sets 8 in Direct Tuning Mode',
                    'name'        => '8-in-direct-mode'
                },
                '9',
                {
                    'description' => 'sets 9 in Direct Tuning Mode',
                    'name'        => '9-in-direct-mode'
                },
                'UP',
                {
                    'description' => 'sets Tuning Frequency Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Tuning Frequency Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Tuning Frequency',
                    'name'        => 'query'
                }
            }
        },
        'PR4',
        {
            'description' => 'Preset Command',
            'name'        => 'preset',
            'values'      => {
                '{1,40}',
                {
                    'description' =>
                      'sets Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'no-1-40'
                },
                '{1,30}',
                {
                    'description' =>
                      'sets Preset No. 1 - 30 { In hexadecimal representation}',
                    'name' => 'no-1-30'
                },
                'UP',
                {
                    'description' => 'sets Preset No. Wrap-Around Up',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'sets Preset No. Wrap-Around Down',
                    'name'        => 'down'
                },
                'QSTN',
                {
                    'description' => 'gets The Preset No.',
                    'name'        => 'query'
                }
            }
        },
        'NTC',
        {
            'description' =>
              'Net-Tune/Network Operation Command{Net-Tune Model Only}',
            'name'   => 'net-usb',
            'values' => {
                'PLAYz',
                {
                    'description' => 'PLAY KEY',
                    'name'        => 'playz'
                },
                'STOPz',
                { 'description' => 'STOP KEY', 'name' => 'stopz' },
                'PAUSEz',
                {
                    'description' => 'PAUSE KEY',
                    'name'        => 'pausez'
                },
                'TRUPz',
                {
                    'description' => 'TRACK UP KEY',
                    'name'        => 'trupz'
                },
                'TRDNz',
                {
                    'description' => 'TRACK DOWN KEY',
                    'name'        => 'trdnz'
                }
            }
        },
        'NT4',
        {
            'description' =>
              'Net-Tune/Network Operation Command{Network Model Only}',
            'name'   => 'net-usb',
            'values' => {
                'PLAY',
                {
                    'description' => 'PLAY KEY',
                    'name'        => 'play'
                },
                'STOP',
                { 'description' => 'STOP KEY', 'name' => 'stop' },
                'PAUSE',
                { 'description' => 'PAUSE KEY', 'name' => 'pause' },
                'TRUP',
                {
                    'description' => 'TRACK UP KEY',
                    'name'        => 'trup'
                },
                'TRDN',
                {
                    'description' => 'TRACK DOWN KEY',
                    'name'        => 'trdn'
                },
                'FF',
                {
                    'description' => 'FF KEY {CONTINUOUS*} {for iPod 1wire}',
                    'name'        => 'ff'
                },
                'REW',
                {
                    'description' => 'REW KEY {CONTINUOUS*} {for iPod 1wire}',
                    'name'        => 'rew'
                },
                'REPEAT',
                {
                    'description' => 'REPEAT KEY{for iPod 1wire}',
                    'name'        => 'repeat'
                },
                'RANDOM',
                {
                    'description' => 'RANDOM KEY{for iPod 1wire}',
                    'name'        => 'random'
                },
                'DISPLAY',
                {
                    'description' => 'DISPLAY KEY{for iPod 1wire}',
                    'name'        => 'display'
                },
                'RIGHT',
                {
                    'description' => 'RIGHT KEY{for iPod 1wire}',
                    'name'        => 'right'
                },
                'LEFT',
                {
                    'description' => 'LEFT KEY{for iPod 1wire}',
                    'name'        => 'left'
                },
                'UP',
                {
                    'description' => 'UP KEY{for iPod 1wire}',
                    'name'        => 'up'
                },
                'DOWN',
                {
                    'description' => 'DOWN KEY{for iPod 1wire}',
                    'name'        => 'down'
                },
                'SELECT',
                {
                    'description' => 'SELECT KEY{for iPod 1wire}',
                    'name'        => 'select'
                },
                'RETURN',
                {
                    'description' => 'RETURN KEY{for iPod 1wire}',
                    'name'        => 'return'
                }
            }
        },
        'NP4',
        {
            'description' =>
              'Internet Radio Preset Command {Network Model Only}',
            'name'   => 'internet-radio-preset',
            'values' => {
                '{1,40}',
                {
                    'description' =>
                      'sets Preset No. 1 - 40 { In hexadecimal representation}',
                    'name' => 'no-1-40'
                }
            }
        }
    },
    'dock' => {
        'CDS',
        {
            'description' => 'Command for Docking Station via RI',
            'name'        => 'command-for-docking-station-via-ri',
            'values'      => {
                'PWRON',
                {
                    'description' => 'sets Dock On',
                    'name'        => 'on'
                },
                'PWROFF',
                {
                    'description' => 'sets Dock Standby',
                    'name'        => 'off'
                },
                'PLY/RES',
                {
                    'description' => 'PLAY/RESUME Key',
                    'name'        => 'ply-res'
                },
                'STOP',
                { 'description' => 'STOP Key', 'name' => 'stop' },
                'SKIP.F',
                {
                    'description' => 'TRACK UP Key',
                    'name'        => 'skip-f'
                },
                'SKIP.R',
                {
                    'description' => 'TRACK DOWN Key',
                    'name'        => 'skip-r'
                },
                'PAUSE',
                { 'description' => 'PAUSE Key', 'name' => 'pause' },
                'PLY/PAU',
                {
                    'description' => 'PLAY/PAUSE Key',
                    'name'        => 'ply-pau'
                },
                'FF',
                { 'description' => 'FF Key', 'name' => 'ff' },
                'REW',
                { 'description' => 'FR Key', 'name' => 'rew' },
                'ALBUM+',
                {
                    'description' => 'ALBUM UP Key',
                    'name'        => 'album'
                },
                'ALBUM-',
                {
                    'description' => 'ALBUM DONW Key',
                    'name'        => 'album'
                },
                'PLIST+',
                {
                    'description' => 'PLAYLIST UP Key',
                    'name'        => 'plist'
                },
                'PLIST-',
                {
                    'description' => 'PLAYLIST DOWN Key',
                    'name'        => 'plist'
                },
                'CHAPT+',
                {
                    'description' => 'CHAPTER UP Key',
                    'name'        => 'chapt'
                },
                'CHAPT-',
                {
                    'description' => 'CHAPTER DOWN Key',
                    'name'        => 'chapt'
                },
                'RANDOM',
                {
                    'description' => 'SHUFFLE Key',
                    'name'        => 'random'
                },
                'REPEAT',
                {
                    'description' => 'REPEAT Key',
                    'name'        => 'repeat'
                },
                'MUTE',
                { 'description' => 'MUTE Key', 'name' => 'mute' },
                'BLIGHT',
                {
                    'description' => 'BACKLIGHT Key',
                    'name'        => 'blight'
                },
                'MENU',
                { 'description' => 'MENU Key', 'name' => 'menu' },
                'ENTER',
                {
                    'description' => 'SELECT Key',
                    'name'        => 'enter'
                },
                'UP',
                { 'description' => 'CUSOR UP Key', 'name' => 'up' },
                'DOWN',
                {
                    'description' => 'CURSOR DOWN Key',
                    'name'        => 'down'
                }
            }
        }
    }
};

#####################################
sub ONKYO_GetRemotecontrolCommand($;$) {
    my ( $zone, $command ) = @_;

    if ( !defined($command) && defined( $ONKYO_cmds_hr->{$zone} ) ) {
        return $ONKYO_cmds_hr->{$zone};
    }
    elsif ( defined( $ONKYO_cmds_hr->{$zone}{$command} ) ) {
        return $ONKYO_cmds_hr->{$zone}{$command};
    }
    else {
        return undef;
    }
}

#####################################
sub ONKYO_GetRemotecontrolValue($$;$) {
    my ( $zone, $command, $value ) = @_;

    if (  !defined($value)
        && defined( $ONKYO_values_hr->{$zone}{$command} ) )
    {
        return $ONKYO_values_hr->{$zone}{$command};
    }
    elsif ( defined( $ONKYO_values_hr->{$zone}{$command}{$value} ) ) {
        return $ONKYO_values_hr->{$zone}{$command}{$value};
    }
    else {
        return undef;
    }
}

#####################################
sub ONKYO_GetRemotecontrolCommandDetails($;$) {
    my ( $zone, $command ) = @_;

    if ( !defined($command) && defined( $ONKYO_cmddb->{$zone} ) ) {
        return $ONKYO_cmddb->{$zone};
    }
    elsif ( defined( $ONKYO_cmddb->{$zone}{$command} ) ) {
        return $ONKYO_cmddb->{$zone}{$command};
    }
    else {
        return undef;
    }
}

1;
