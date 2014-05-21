/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.hadoop.hive.ql.optimizer.ppr;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.Map.Entry;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.hive.conf.HiveConf;
import org.apache.hadoop.hive.ql.exec.ExprNodeEvaluator;
import org.apache.hadoop.hive.ql.exec.ExprNodeEvaluatorFactory;
import org.apache.hadoop.hive.ql.exec.FunctionRegistry;
import org.apache.hadoop.hive.ql.lib.DefaultGraphWalker;
import org.apache.hadoop.hive.ql.lib.DefaultRuleDispatcher;
import org.apache.hadoop.hive.ql.lib.Dispatcher;
import org.apache.hadoop.hive.ql.lib.GraphWalker;
import org.apache.hadoop.hive.ql.lib.Node;
import org.apache.hadoop.hive.ql.lib.NodeProcessor;
import org.apache.hadoop.hive.ql.lib.Rule;
import org.apache.hadoop.hive.ql.lib.RuleRegExp;
import org.apache.hadoop.hive.ql.metadata.HiveException;
import org.apache.hadoop.hive.ql.metadata.TablePartition;
import org.apache.hadoop.hive.ql.optimizer.Transform;
import org.apache.hadoop.hive.ql.parse.ParseContext;
import org.apache.hadoop.hive.ql.parse.PrunedPartitionList;
import org.apache.hadoop.hive.ql.parse.SemanticException;
import org.apache.hadoop.hive.ql.parse.TypeCheckProcFactory;
import org.apache.hadoop.hive.ql.plan.exprNodeColumnDesc;
import org.apache.hadoop.hive.ql.plan.exprNodeDesc;
import org.apache.hadoop.hive.ql.plan.exprNodeGenericFuncDesc;
import org.apache.hadoop.hive.ql.udf.UDFOPAnd;
import org.apache.hadoop.hive.ql.udf.UDFOPEqual;
import org.apache.hadoop.hive.ql.udf.UDFOPEqualOrGreaterThan;
import org.apache.hadoop.hive.ql.udf.UDFOPEqualOrLessThan;
import org.apache.hadoop.hive.ql.udf.UDFOPGreaterThan;
import org.apache.hadoop.hive.ql.udf.UDFOPLessThan;
import org.apache.hadoop.hive.ql.udf.UDFOPNot;
import org.apache.hadoop.hive.ql.udf.UDFOPOr;
import org.apache.hadoop.hive.serde2.objectinspector.ObjectInspector;
import org.apache.hadoop.hive.serde2.objectinspector.ObjectInspectorConverters;
import org.apache.hadoop.hive.serde2.objectinspector.ObjectInspectorFactory;
import org.apache.hadoop.hive.serde2.objectinspector.PrimitiveObjectInspector;
import org.apache.hadoop.hive.serde2.objectinspector.PrimitiveObjectInspector.PrimitiveCategory;
import org.apache.hadoop.hive.serde2.objectinspector.primitive.PrimitiveObjectInspectorFactory;
import org.apache.hadoop.hive.serde2.typeinfo.PrimitiveTypeInfo;
import org.apache.hadoop.hive.serde2.typeinfo.TypeInfo;
import org.apache.hadoop.hive.serde2.typeinfo.TypeInfoFactory;

public class PartitionPruner implements Transform {

  private static final Log LOG = LogFactory
      .getLog("hive.ql.optimizer.ppr.PartitionPruner");

  @Override
  public ParseContext transform(ParseContext pctx) throws SemanticException {

    OpWalkerCtx opWalkerCtx = new OpWalkerCtx(pctx.getOpToPartPruner());

    Map<Rule, NodeProcessor> opRules = new LinkedHashMap<Rule, NodeProcessor>();
    opRules.put(new RuleRegExp("R1", "(TS%FIL%)|(TS%FIL%FIL%)"),
        OpProcFactory.getFilterProc());

    Dispatcher disp = new DefaultRuleDispatcher(OpProcFactory.getDefaultProc(),
        opRules, opWalkerCtx);
    GraphWalker ogw = new DefaultGraphWalker(disp);

    ArrayList<Node> topNodes = new ArrayList<Node>();
    topNodes.addAll(pctx.getTopOps().values());
    ogw.startWalking(topNodes, null);
    pctx.setHasNonPartCols(opWalkerCtx.getHasNonPartCols());

    return pctx;
  }

  private static class PartitionPrunerContext {
    ObjectInspector partKeysInpsector;
    int numPartitionLevels;
    List<String> partKeyNames;
    Map<String, ObjectInspectorConverters.Converter> partKeyConverters;
    Map<String, Set<String>> partKeyToTotalPartitions;
    Map<String, org.apache.hadoop.hive.metastore.api.Partition> partitionMap;
  }

  private static List<exprNodeDesc> evaluatePrunedExpression(
      exprNodeDesc prunerExpr, PartitionPrunerContext ppc,
      Map<String, Set<String>> partColToTargetPartitions) throws HiveException {
    boolean isFunction = prunerExpr instanceof exprNodeGenericFuncDesc;
    if (!isFunction) {
      if (prunerExpr instanceof exprNodeColumnDesc) {
        List<exprNodeDesc> partExprList = new ArrayList<exprNodeDesc>();
        partExprList.add(prunerExpr);
        return partExprList;
      } else {
        return null;
      }
    }

    List<exprNodeDesc> children = prunerExpr.getChildren();
    List<Map<String, Set<String>>> childrenPartitions = new ArrayList<Map<String, Set<String>>>();
    List<List<exprNodeDesc>> partDescsFromChildren = new ArrayList<List<exprNodeDesc>>();
    List<exprNodeDesc> returnPartDescs = new ArrayList<exprNodeDesc>();

    for (exprNodeDesc child : children) {
      Map<String, Set<String>> partMap = new HashMap<String, Set<String>>();
      List<exprNodeDesc> results = evaluatePrunedExpression(child, ppc, partMap);
      partDescsFromChildren.add(results);
      if (results != null) {
        addAndDeduplicate(returnPartDescs, results);
      }
      childrenPartitions.add(partMap);
    }

    int numPartExprs = returnPartDescs.size();
    if (FunctionRegistry.isOpOr(prunerExpr)) {
      for (String partKeyName : ppc.partKeyNames) {
        Set<String> leftParts = childrenPartitions.get(0).get(partKeyName);
        Set<String> rightParts = childrenPartitions.get(1).get(partKeyName);
        if (leftParts != null && rightParts == null) {
          rightParts = ppc.partKeyToTotalPartitions.get(partKeyName);
        } else if (rightParts != null && leftParts == null) {
          leftParts = rightParts;
          rightParts = ppc.partKeyToTotalPartitions.get(partKeyName);
        } else if (rightParts == null && leftParts == null) {
          continue;
        }
        leftParts.addAll(rightParts);
        partColToTargetPartitions.put(partKeyName, leftParts);
      }
    } else if (FunctionRegistry.isOpAnd(prunerExpr)) {
      for (Map<String, Set<String>> childPartMap : childrenPartitions) {
        for (Entry<String, Set<String>> entry : childPartMap.entrySet()) {
          Set<String> partitions = partColToTargetPartitions
              .get(entry.getKey());
          if (partitions == null) {
            partitions = entry.getValue();
            partColToTargetPartitions.put(entry.getKey(), partitions);
          } else
            partitions.retainAll(entry.getValue());
        }
      }
    } else if (FunctionRegistry.isOpNot(prunerExpr)) {
      assert (childrenPartitions.size() < 2);
      if (childrenPartitions.size() == 1) {
        Map<String, Set<String>> partMap = childrenPartitions.get(0);
        for (Entry<String, Set<String>> entry : partMap.entrySet()) {
          Set<String> targetPartitions = new TreeSet<String>();
          Set<String> partitions = entry.getValue();
          Set<String> totalPartitions = ppc.partKeyToTotalPartitions.get(entry
              .getKey());
          for (String i : totalPartitions) {
            if (!partitions.contains(i))
              targetPartitions.add(i);
          }

          partColToTargetPartitions.put(entry.getKey(), targetPartitions);
        }
      }
    }

    boolean isEqualUDF = FunctionRegistry.isOpEqual(prunerExpr);
    if ((isEqualUDF || FunctionRegistry.isOpEqualOrGreaterThan(prunerExpr)
        || FunctionRegistry.isOpEqualOrLessThan(prunerExpr)
        || FunctionRegistry.isOpGreaterThan(prunerExpr) || FunctionRegistry
          .isOpLessThan(prunerExpr)) && numPartExprs == 1) {
      assert (partDescsFromChildren.size() == 2);
      exprNodeGenericFuncDesc funcDesc = (exprNodeGenericFuncDesc) prunerExpr;

      if (partDescsFromChildren.get(0) == null
          || partDescsFromChildren.get(0).size() == 0) {
        exprNodeDesc temp = funcDesc.getChildExprs().get(0);
        funcDesc.getChildExprs().set(0, funcDesc.getChildExprs().get(1));
        funcDesc.getChildExprs().set(1, temp);

        String newMethodName = null;
        if (FunctionRegistry.isOpEqualOrGreaterThan(prunerExpr)) {
          newMethodName = "<=";
        } else if (FunctionRegistry.isOpEqualOrLessThan(prunerExpr)) {
          newMethodName = ">=";
        } else if (FunctionRegistry.isOpGreaterThan(prunerExpr)) {
          newMethodName = "<";
        } else if (FunctionRegistry.isOpLessThan(prunerExpr)) {
          newMethodName = ">";
        }

        if (newMethodName != null) {
          ArrayList<TypeInfo> argumentTypeInfos = new ArrayList<TypeInfo>(
              funcDesc.getChildExprs().size());
          for (int i = 0; i < children.size(); i++) {
            exprNodeDesc child = funcDesc.getChildExprs().get(i);
            argumentTypeInfos.add(child.getTypeInfo());
          }
          funcDesc.setGenericUDF(FunctionRegistry
              .getFunctionInfo(newMethodName).getGenericUDF());
        }
      }

      exprNodeColumnDesc partColDesc = (exprNodeColumnDesc) returnPartDescs
          .get(0);
      String partColName = partColDesc.getColumn();
      org.apache.hadoop.hive.metastore.api.Partition part = ppc.partitionMap
          .get(partColName);
      boolean isRangePartition = part.getParType().equalsIgnoreCase("RANGE");
      boolean isHashPartition = part.getParType().equalsIgnoreCase("HASH");

      boolean exprRewritten = false;
      boolean containEqual = false;
      Set<String> tempPartitions;
      if (isRangePartition) {
        exprNodeGenericFuncDesc boundaryCheckerDesc = null;
        if (FunctionRegistry.isOpEqualOrGreaterThan(prunerExpr)
            || FunctionRegistry.isOpGreaterThan(prunerExpr)) {
          boundaryCheckerDesc = (exprNodeGenericFuncDesc) TypeCheckProcFactory
              .getDefaultExprProcessor().getFuncExprNodeDesc("=",
                  funcDesc.getChildExprs());

          List<exprNodeDesc> argDescs = new ArrayList<exprNodeDesc>();
          argDescs.add(funcDesc);
          funcDesc = (exprNodeGenericFuncDesc) TypeCheckProcFactory
              .getDefaultExprProcessor().getFuncExprNodeDesc("not", argDescs);
          exprRewritten = true;
          if (FunctionRegistry.isOpGreaterThan(prunerExpr))
            containEqual = true;
        } else if (FunctionRegistry.isOpEqual(prunerExpr)) {
          funcDesc = (exprNodeGenericFuncDesc) TypeCheckProcFactory
              .getDefaultExprProcessor().getFuncExprNodeDesc("<=",
                  funcDesc.getChildExprs());
        }

        tempPartitions = evaluateRangePartition(funcDesc, boundaryCheckerDesc,
            ppc.partKeysInpsector, ppc.partKeyConverters.get(partColName),
            part.getParSpaces(), part.getLevel(), ppc.numPartitionLevels,
            isEqualUDF, exprRewritten, containEqual);

        if (tempPartitions.isEmpty()
            && part.getParSpaces().containsKey("default")) {
          tempPartitions.add("default");
        }
      } else if (isHashPartition) {

        tempPartitions = evaluateHashPartition(funcDesc, ppc.partKeysInpsector,
            ppc.partKeyConverters.get(partColName), part.getParSpaces(),
            part.getLevel(), ppc.numPartitionLevels);
      } else {
        tempPartitions = evaluateListPartition(funcDesc, ppc.partKeysInpsector,
            ppc.partKeyConverters.get(partColName), part.getParSpaces(),
            part.getLevel(), ppc.numPartitionLevels);

        if (tempPartitions.isEmpty()
            && part.getParSpaces().containsKey("default")) {
          tempPartitions.add("default");
        }
      }

      Set<String> targetPartitions = partColToTargetPartitions.get(partColDesc
          .getColumn());
      if (targetPartitions == null) {
        targetPartitions = tempPartitions;
        partColToTargetPartitions
            .put(partColDesc.getColumn(), targetPartitions);
      } else {
        targetPartitions.addAll(tempPartitions);
      }

    }

    return returnPartDescs;
  }

  private static void addAndDeduplicate(List<exprNodeDesc> target,
      List<exprNodeDesc> source) {
    if (target.size() == 0) {
      target.addAll(source);
      return;
    }
    for (exprNodeDesc srcDesc : source) {
      boolean added = false;
      for (exprNodeDesc targetDesc : source) {
        if (srcDesc.isSame(targetDesc)) {
          added = true;
          break;
        }
      }
      if (added)
        target.add(srcDesc);
    }
  }

  private static Set<String> evaluateRangePartition(exprNodeDesc desc,
      exprNodeDesc boundaryCheckerDesc, ObjectInspector partKeysInspector,
      ObjectInspectorConverters.Converter converter,
      Map<String, List<String>> partSpace, int level, int numPartitionLevel,
      boolean isEqualFunc, boolean exprRewritten, boolean containsEqual)
      throws HiveException {
    ArrayList<Object> partObjects = new ArrayList<Object>(numPartitionLevel);
    for (int i = 0; i < numPartitionLevel; i++) {
      partObjects.add(null);
    }

    ExprNodeEvaluator evaluator = ExprNodeEvaluatorFactory.get(desc);
    ObjectInspector evaluateResultOI = evaluator.initialize(partKeysInspector);

    Set<String> targetPartitions = new LinkedHashSet<String>();

    for (Entry<String, List<String>> entry : partSpace.entrySet()) {
      List<String> partValues = entry.getValue();

      if (partValues == null || partValues.size() == 0) {
        assert (entry.getKey().equalsIgnoreCase("default"));
        targetPartitions.add(entry.getKey());
        break;
      }

      Object pv = converter.convert(partValues.get(0));
      partObjects.set(level, pv);
      Object evaluateResultO = evaluator.evaluate(partObjects);
      Boolean r = (Boolean) ((PrimitiveObjectInspector) evaluateResultOI)
          .getPrimitiveJavaObject(evaluateResultO);
      if (r == null) {
        targetPartitions.clear();
        break;
      } else {
        if (Boolean.TRUE.equals(r)) {
          if (!isEqualFunc)
            targetPartitions.add(entry.getKey());
        } else if (Boolean.FALSE.equals(r)) {
          if (boundaryCheckerDesc != null) {
            ExprNodeEvaluator boundaryChecker = ExprNodeEvaluatorFactory
                .get(boundaryCheckerDesc);
            ObjectInspector boundaryCheckerOI = boundaryChecker
                .initialize(partKeysInspector);
            Boolean isBoundary = (Boolean) ((PrimitiveObjectInspector) boundaryCheckerOI)
                .getPrimitiveJavaObject(boundaryChecker.evaluate(partObjects));
            if (isBoundary == null) {
              targetPartitions.clear();
              break;
            } else {
              if (Boolean.FALSE.equals(isBoundary)) {
                break;
              }
            }
          }
          if (!(exprRewritten && containsEqual)) {
            targetPartitions.add(entry.getKey());
          }
          break;
        }
      }
    }

    if (exprRewritten) {
      Set<String> oldPartitions = targetPartitions;
      targetPartitions = new TreeSet<String>();
      targetPartitions.addAll(partSpace.keySet());
      Iterator<String> iter = targetPartitions.iterator();
      while (iter.hasNext()) {
        if (oldPartitions.contains(iter.next()))
          iter.remove();
      }
    }

    return targetPartitions;
  }

  private static Set<String> evaluateListPartition(exprNodeDesc desc,
      ObjectInspector partKeysInpsector,
      ObjectInspectorConverters.Converter converter,
      Map<String, List<String>> partSpace, int level, int numPartitionLevels)
      throws HiveException {
    ExprNodeEvaluator evaluator = ExprNodeEvaluatorFactory.get(desc);
    ObjectInspector evaluateResultOI = evaluator.initialize(partKeysInpsector);

    Set<String> targetPartitions = new TreeSet<String>();

    ArrayList<Object> partObjects = new ArrayList<Object>(numPartitionLevels);
    for (int i = 0; i < numPartitionLevels; i++) {
      partObjects.add(null);
    }
    for (Entry<String, List<String>> entry : partSpace.entrySet()) {
      List<String> partValues = entry.getValue();

      for (String partVal : partValues) {
        Object pv = converter.convert(partVal);
        partObjects.set(level, pv);
        Object evaluateResultO = evaluator.evaluate(partObjects);
        Boolean r = (Boolean) ((PrimitiveObjectInspector) evaluateResultOI)
            .getPrimitiveJavaObject(evaluateResultO);
        if (r == null) {
          return new TreeSet<String>();
        } else {
          if (Boolean.TRUE.equals(r)) {
            targetPartitions.add(entry.getKey());
          }
        }
      }
    }

    return targetPartitions;
  }

  private static Set<String> evaluateHashPartition(exprNodeDesc desc,
      ObjectInspector partKeysInpsector,
      ObjectInspectorConverters.Converter converter,
      Map<String, List<String>> partSpace, int level, int numPartitionLevels)
      throws HiveException {

    Set<String> targetPartitions = new TreeSet<String>();
    for (Entry<String, List<String>> entry : partSpace.entrySet()) {
      targetPartitions.add(entry.getKey());
    }

    return targetPartitions;
  }

  public static PrunedPartitionList prune(TablePartition tab,
      exprNodeDesc prunerExpr, HiveConf conf, String alias)
      throws HiveException {
    LOG.trace("Started pruning partiton");
    LOG.trace("tabname = " + tab.getName());
    LOG.trace("prune Expression = " + prunerExpr);

    Set<String> targetPartitionPaths = new TreeSet<String>();

    if (tab.isPartitioned()) {
      PartitionPrunerContext ppc = new PartitionPrunerContext();

      ppc.partKeyConverters = new HashMap<String, ObjectInspectorConverters.Converter>();
      ppc.partKeyToTotalPartitions = new HashMap<String, Set<String>>();
      ppc.partitionMap = new HashMap<String, org.apache.hadoop.hive.metastore.api.Partition>();
      org.apache.hadoop.hive.metastore.api.Partition partition = tab
          .getTTable().getPriPartition();
      ppc.partitionMap.put(partition.getParKey().getName(), partition);
      partition = tab.getTTable().getSubPartition();
      if (partition != null) {
        ppc.partitionMap.put(partition.getParKey().getName(), partition);
      }
      ppc.numPartitionLevels = ppc.partitionMap.size();

      ppc.partKeyNames = new ArrayList<String>();
      ArrayList<ObjectInspector> partObjectInspectors = new ArrayList<ObjectInspector>();
      for (int i = 0; i < ppc.numPartitionLevels; i++) {
        ppc.partKeyNames.add(null);
        partObjectInspectors.add(null);
      }
      for (org.apache.hadoop.hive.metastore.api.Partition part : ppc.partitionMap
          .values()) {
        ppc.partKeyNames.set(part.getLevel(), part.getParKey().getName());
        ObjectInspector partOI = PrimitiveObjectInspectorFactory
            .getPrimitiveWritableObjectInspector(((PrimitiveTypeInfo) TypeInfoFactory
                .getPrimitiveTypeInfo(part.getParKey().getType()))
                .getPrimitiveCategory());
        partObjectInspectors.set(part.getLevel(), partOI);

        ObjectInspector partStringOI = PrimitiveObjectInspectorFactory
            .getPrimitiveJavaObjectInspector(PrimitiveCategory.STRING);
        ppc.partKeyConverters.put(part.getParKey().getName(),
            ObjectInspectorConverters.getConverter(partStringOI, partOI));
        ppc.partKeyToTotalPartitions.put(part.getParKey().getName(), part
            .getParSpaces().keySet());
      }
      ppc.partKeysInpsector = ObjectInspectorFactory
          .getStandardStructObjectInspector(ppc.partKeyNames,
              partObjectInspectors);

      Map<String, Set<String>> partColToPartitionNames = new HashMap<String, Set<String>>();
      evaluatePrunedExpression(prunerExpr, ppc, partColToPartitionNames);
      String priPartColName = ppc.partKeyNames.get(0);
      Set<String> priPartNames = partColToPartitionNames.get(priPartColName);
      if (priPartNames == null)
        priPartNames = ppc.partKeyToTotalPartitions.get(priPartColName);
      String subPartColName = null;
      Set<String> subPartNames = null;
      if (ppc.partKeyNames.size() > 1) {
        subPartColName = ppc.partKeyNames.get(1);
        subPartNames = partColToPartitionNames.get(subPartColName);
        if (subPartNames == null)
          subPartNames = ppc.partKeyToTotalPartitions.get(subPartColName);
      }

      for (String priPartName : priPartNames) {
        if (subPartNames != null) {
          for (String subPartName : subPartNames) {
            targetPartitionPaths.add(new Path(tab.getPath(), priPartName + "/"
                + subPartName).toString());
          }
        } else {
          targetPartitionPaths.add(new Path(tab.getPath(), priPartName)
              .toString());
        }
      }
    } else {
      targetPartitionPaths.add(tab.getPath().toString());
    }

    return new PrunedPartitionList(targetPartitionPaths);

  }

  public static boolean hasColumnExpr(exprNodeDesc desc) {
    if (desc == null) {
      return false;
    }
    if (desc instanceof exprNodeColumnDesc) {
      return true;
    }
    List<exprNodeDesc> children = desc.getChildren();
    if (children != null) {
      for (int i = 0; i < children.size(); i++) {
        if (hasColumnExpr(children.get(i))) {
          return true;
        }
      }
    }
    return false;
  }

}
