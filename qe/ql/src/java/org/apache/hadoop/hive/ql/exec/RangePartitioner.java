/**
* Tencent is pleased to support the open source community by making TDW available.
* Copyright (C) 2014 THL A29 Limited, a Tencent company. All rights reserved.
* Licensed under the Apache License, Version 2.0 (the "License"); you may not use 
* this file except in compliance with the License. You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software distributed 
* under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS 
* OF ANY KIND, either express or implied. See the License for the specific language governing
* permissions and limitations under the License.
*/
package org.apache.hadoop.hive.ql.exec;

import org.apache.hadoop.hive.ql.metadata.HiveException;
import org.apache.hadoop.io.IntWritable;

public class RangePartitioner implements Partitioner {

  ExprNodeEvaluator[] partValueSpaces;
  int defaultPart;

  public RangePartitioner(ExprNodeEvaluator[] partValueSpaces, int defaultPart) {
    this.partValueSpaces = partValueSpaces;
    this.defaultPart = defaultPart;
  }

  public int getPartition(Object row) throws HiveException {
    int low = 0;
    int high = defaultPart < 0 ? partValueSpaces.length - 1
        : partValueSpaces.length - 2;

    while (low <= high) {
      int mid = (low + high) >>> 1;

      IntWritable cmpWritable = (IntWritable) partValueSpaces[mid]
          .evaluate(row);
      if (cmpWritable == null) {
        if (defaultPart == -1)
          throw new HiveException(
              "No default partition defined to accept a null part key.");
        return defaultPart;
      }

      int cmp = cmpWritable.get();
      if (cmp < 0)
        low = mid + 1;
      else if (cmp > 0)
        high = mid - 1;
      else
        return mid + 1;
    }

    return low;
  }

}
