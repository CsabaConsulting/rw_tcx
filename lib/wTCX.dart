// wTCX.dart
// Tools to generate a TCX file
// To test on Strava

import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

import 'models/TCXModel.dart';
import 'logTool.dart';

class StatisticsAccumulator {
  bool calculateMaxSpeed;
  bool calculateAverageHeartRate;
  bool calculateMaxHeartRate;
  bool calculateAverageCadence;

  double maxSpeed;
  int heartRateSum;
  int heartRateCount;
  int maxHeartRate;
  int cadenceSum;
  int cadenceCount;

  int get averageHeartRate =>
      heartRateCount > 0 ? heartRateSum / heartRateCount : 0;
  int get averageCadence => cadenceCount > 0 ? cadenceSum / cadenceCount : 0;

  StatisticsAccumulator(
      {this.calculateMaxSpeed,
      this.calculateAverageHeartRate,
      this.calculateMaxHeartRate,
      this.calculateAverageCadence}) {
    if (calculateMaxSpeed) {
      maxSpeed = 0;
    }
    if (calculateAverageHeartRate) {
      heartRateSum = 0;
      heartRateCount = 0;
    }
    if (calculateMaxHeartRate) {
      maxHeartRate = 0;
    }
    if (calculateAverageCadence) {
      cadenceSum = 0;
      cadenceCount = 0;
    }
  }

  processTrackPoint(TrackPoint trackPoint) {
    if (calculateMaxSpeed && trackPoint.speed != null) {
      maxSpeed = max(maxSpeed, trackPoint.speed);
    }
    if (trackPoint.heartRate != null && trackPoint.heartRate > 0) {
      if (calculateAverageHeartRate) {
        heartRateSum += trackPoint.heartRate;
        heartRateCount++;
      }
      if (calculateMaxHeartRate) {
        maxHeartRate = max(maxHeartRate, trackPoint.heartRate);
      }
    }
    if (calculateAverageCadence &&
        trackPoint.cadence != null &&
        trackPoint.cadence > 0) {
      cadenceSum += trackPoint.cadence;
      cadenceCount++;
    }
  }
}

// Generate the TCX file
/// from a TCX Model
/// Store the TCX file in genera
/// TODO: Add return code
///
// Future<String> writeTCX(TCXModel tcxInfo, String filename) async {
Future<void> writeTCX(TCXModel tcxInfo, String filename) async {
  Future<File> _localFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    var path = directory.path;
    return File('$path/$fileName');
  }

  // Now generate a new file from rideData
  var generatedTCXFile = await _localFile(filename);
  var sink = generatedTCXFile.openWrite(mode: FileMode.writeOnly);

  String contents = '';

  // Generate the prolog of the TCX file
  final String prolog = """ <?xml version="1.0" encoding="UTF-8"?>
    <TrainingCenterDatabase
    xsi:schemaLocation="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd"
    xmlns:ns5="http://www.garmin.com/xmlschemas/ActivityGoals/v1"
    xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2"
    xmlns:ns2="http://www.garmin.com/xmlschemas/UserProfile/v2"
    xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:ns4="http://www.garmin.com/xmlschemas/ProfileExtension/v1">\n""";

  final String tailActivity = """      <Creator xsi:type="Device_t">
        <Name>${tcxInfo.deviceName}</Name>
        <UnitId>${tcxInfo.unitID}</UnitId>
        <ProductID>${tcxInfo.productID}</ProductID>
        <Version>
          <VersionMajor>${tcxInfo.versionMajor}</VersionMajor>
          <VersionMinor>${tcxInfo.versionMinor}</VersionMinor>
          <BuildMajor>${tcxInfo.buildMajor}</BuildMajor>
          <BuildMinor>${tcxInfo.buildMinor}</BuildMinor>
        </Version>
      </Creator>
  </Activity> """;

  final String tail = """    <Author xsi:type="Application_t">
    <Name>${tcxInfo.author}</Name>
    <Build>
      <Version>
        <VersionMajor>${tcxInfo.versionMajor}</VersionMajor>
        <VersionMinor>${tcxInfo.versionMinor}</VersionMinor>
        <BuildMajor>${tcxInfo.buildMajor}</BuildMajor>
        <BuildMinor>${tcxInfo.buildMinor}</BuildMinor>
      </Version>
    </Build>
    <LangID>${tcxInfo.langID}</LangID>
    <PartNumber>${tcxInfo.partNumber}</PartNumber>
  </Author>
  </TrainingCenterDatabase>""";

  String activityBiking = """<Activity Sport="${tcxInfo.activityType}">\n""";

  String activitiesContent = '';

  // Add Activity
  //-------------
  String activityContent = activityBiking;

  // Add ID
  activityContent += addElement('Id', createTimestamp(tcxInfo.dateActivity));

  displayInfo(' $activityContent');

  // Add lap
  //---------
  // Assuming that points are ordered by time stamp ascending
  TrackPoint lastTrackPoint = tcxInfo.points.last;
  if (lastTrackPoint != null) {
    if ((tcxInfo.totalTime == null || tcxInfo.totalTime == 0) &&
        lastTrackPoint.date != null) {
      tcxInfo.totalTime = lastTrackPoint.date.millisecondsSinceEpoch / 1000;
    }
    if ((tcxInfo.totalDistance == null || tcxInfo.totalDistance == 0) &&
        lastTrackPoint.distance > 0) {
      tcxInfo.totalDistance = lastTrackPoint.distance;
    }
  }
  String lapContent = '';
  lapContent += addElement('TotalTimeSeconds', tcxInfo.totalTime.toString());
  // Add Total distance in meters
  lapContent += addElement('DistanceMeters', tcxInfo.totalDistance.toString());

  final calculateMaxSpeed = tcxInfo.maxSpeed == null || tcxInfo.maxSpeed == 0;
  final calculateAverageHeartRate =
      tcxInfo.averageHeartRate == null || tcxInfo.averageHeartRate == 0;
  final calculateMaxHeartRate =
      tcxInfo.maximumHeartRate == null || tcxInfo.maximumHeartRate == 0;
  final calculateAverageCadence =
      tcxInfo.averageCadence == null || tcxInfo.averageCadence == 0;
  StatisticsAccumulator accu;
  if (calculateMaxSpeed ||
      calculateAverageHeartRate ||
      calculateMaxHeartRate ||
      calculateAverageCadence) {
    var accuInit = StatisticsAccumulator(
        calculateMaxSpeed: calculateMaxSpeed,
        calculateAverageHeartRate: calculateAverageHeartRate,
        calculateMaxHeartRate: calculateMaxHeartRate,
        calculateAverageCadence: calculateAverageCadence);
    accu = tcxInfo.points.fold<StatisticsAccumulator>(accuInit,
        (accumulator, trackPoint) => accumulator.processTrackPoint(trackPoint));
  }
  if (calculateMaxSpeed) {
    tcxInfo.maxSpeed = accu.maxSpeed;
  }
  if (calculateAverageHeartRate) {
    tcxInfo.averageHeartRate = accu.averageHeartRate;
  }
  if (calculateMaxHeartRate) {
    tcxInfo.maximumHeartRate = accu.maxHeartRate;
  }
  if (calculateAverageCadence) {
    tcxInfo.averageCadence = accu.averageCadence;
  }

  // Add Maximum speed in meter/second
  lapContent += addElement('MaximumSpeed', tcxInfo.maxSpeed.toString());

  if (tcxInfo.averageHeartRate != null) {
    lapContent +=
        addElement('AverageHeartRateBpm', tcxInfo.averageHeartRate.toString());
  }
  if (tcxInfo.maximumHeartRate != null) {
    lapContent +=
        addElement('MaximumHeartRateBpm', tcxInfo.maximumHeartRate.toString());
  }
  if (tcxInfo.averageCadence != null) {
    final cadence = min(max(tcxInfo.averageCadence, 0), 254).toInt();
    lapContent += addElement('Cadence', cadence.toString());
  }

  // Add calories
  lapContent += addElement('Calories', tcxInfo.calories.toString());
  // Add intensity (what is the meaning?)
  lapContent += addElement('Intensity', 'Active');
  // Add intensity (what is the meaning?)
  lapContent += addElement('TriggerMethod', 'Manual');

  // Add track inside the lap
  String trackContent = '';
  int counterTrackpoint = 0;

  for (var point in tcxInfo.points) {
    String trackPoint = addTrackPoint(point);
    counterTrackpoint++;

    // To display the first 3 trackPoints
    if (counterTrackpoint < 4) {
      displayInfo(' $trackPoint');
    } // temp disp for the for loop

    trackContent = trackContent + trackPoint;
  }
  lapContent = lapContent + addElement('Track', trackContent);

  activityContent += addAttribute(
      'Lap', 'StartTime', createTimestamp(tcxInfo.dateActivity), lapContent);

  activityContent = activityContent + tailActivity;

  activitiesContent = addElement('Activities', activityContent);

  // Create the complete tcx file
  contents = prolog + activitiesContent + tail;

  sink.write(contents);
  // Close the file
  await sink.flush();
  await sink.close();

// return contents;
}

/// Generate a string that will include
/// all the tags corresponding to TCX trackpoint
///
/// Extension handling is missing for the moment
///
String addTrackPoint(TrackPoint point) {
  String _returnString;

  _returnString = "<Trackpoint>\n";
  _returnString += addElement('Time', point.timeStamp);
  _returnString +=
      addPosition(point.latitude.toString(), point.longitude.toString());
  _returnString += addElement('AltitudeMeters', point.altitude.toString());
  _returnString += addElement('DistanceMeters', point.distance.toString());
  if (point.cadence != null) {
    final cadence = min(max(point.cadence, 0), 254).toInt();
    _returnString += addElement('Cadence', cadence.toString());
  }

  if (point.speed != null) {
    _returnString += addExtension('Speed', point.speed);
  }

  if (point.power != null) {
    _returnString += addExtension('Watts', point.power);
  }

  if (point.heartRate != null) {
    _returnString += addHeartRate(point.heartRate);
  }

  _returnString += "</Trackpoint>\n";

  return _returnString;
}

/// Add an extension like
///
///  <Extensions>
///              <ns3:TPX>
///                <ns3:Speed>1.996999979019165</ns3:Speed>
///              </ns3:TPX>
///            </Extensions>
///
/// Does not handle mutiple values like
/// Speed AND Watts in the same extension
///
String addExtension(String tag, double value) {
  double _value = value ?? 0.0;
  return """  <Extensions>
    <ns3:TPX>
      <ns3:$tag>${_value.toString()}</ns3:$tag>
    </ns3:TPX>
  </Extensions>\n""";
}

/// Add heartRate in TCX file to look like
///
///       <HeartRateBpm>
///         <Value>61</Value>
///       </HeartRateBpm>
///
String addHeartRate(int heartRate) {
  int _heartRate = heartRate ?? 0;
  return """                 <HeartRateBpm>
              <Value>${_heartRate.toString()}</Value>
            </HeartRateBpm>\n""";
}

/// create a position something like
/// <Position>
///   <LatitudeDegrees>43.14029800705612</LatitudeDegrees>
///   <LongitudeDegrees>5.771340150386095</LongitudeDegrees>
/// </Position>
String addPosition(String latitude, String longitude) {
  return """<Position>
   <LatitudeDegrees>$latitude</LatitudeDegrees>
   <LongitudeDegrees>$longitude</LongitudeDegrees>
</Position>\n""";
}

/// create XML element
/// from content string
String addElement(String tag, String content) {
  return '<$tag>$content</$tag>\n';
}

/// create XML attribute
/// from content string

String addAttribute(
    String tag, String attribute, String value, String content) {
  return '<$tag $attribute="$value">\n$content</$tag>\n';
}

/// Create timestamp for <Time> element in TCX file
///
/// To get 2019-03-03T11:43:46.000Z
/// utc time
/// Need to add T in the middle
String createTimestamp(DateTime dateTime) {
  return dateTime.toUtc().toString().replaceFirst(' ', 'T');
}
